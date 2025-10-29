class ProductsController < ApplicationController
    require "csv"
  
    # Export all warranties for the connected Gmail user as CSV
    def export
      unless session[:gmail_uid]
        redirect_to root_path, alert: "Please connect Gmail first."
        return
      end
  
      # Fetch warranties for the current Gmail user
      products = Product.for_user(session[:gmail_uid]).to_a.sort_by do |p|
        # Sort by computed expiry_date, put nils at the end
        p.expiry_date || Date.new(3000, 1, 1)
      end
  
      respond_to do |format|
        format.csv do
          headers["Content-Disposition"] = "attachment; filename=warranties.csv"
          headers["Content-Type"]        = "text/csv"
  
          render plain: CSV.generate(headers: true) { |csv|
            csv << %w[
              id
              product_name
              merchant
              purchase_date
              warranty_months
              expiry_date
              status
            ]
  
            products.each do |p|
              csv << [
                p.id,
                p.product_name,
                p.merchant,
                p.purchase_date,
                p.warranty_months,
                p.expiry_date,
                p.status 
              ]
            end
          }
        end
      end
    end

    def calendar
        unless session[:gmail_uid]
          redirect_to root_path, alert: "Please connect Gmail first."
          return
        end
      
        require "icalendar"
      
        products = Product.for_user(session[:gmail_uid]).to_a
      
        # Keep 0 (same-day) AND positive offsets; dedupe & sort
        offsets = Array(params[:reminders])
                    .map { |s| Integer(s) rescue nil }
                    .compact
                    .select { |n| n >= 0 }
                    .uniq
                    .sort
      
        cal = Icalendar::Calendar.new
        cal.x_wr_calname = "Warranty Buddy – Warranties"
        cal.prodid = "-//Warranty Buddy//Iteration 1//EN"
      
        products.each do |p|
          next unless p.expiry_date
      
          cal.event do |e|
            # Make these all-day events explicitly (DATE, not DATE-TIME)
            e.dtstart     = Icalendar::Values::Date.new(p.expiry_date)
            e.dtend       = Icalendar::Values::Date.new(p.expiry_date + 1.day)
            e.summary     = "Warranty expires: #{p.product_name}"
            e.description = "Merchant: #{p.merchant}\nPurchase: #{p.purchase_date}\nWarranty: #{p.warranty_months} month(s)\nStatus: #{p.status}"
            e.uid         = "warranty-expiry-#{p.id}@warranty-buddy"
            e.transp      = "TRANSPARENT"
      
            tz = ActiveSupport::TimeZone["America/New_York"]

            offsets.each do |days|
                e.alarm do |a|
                    a.action      = "DISPLAY"
                    a.description = "Warranty expiring soon: #{p.product_name}"

                    alert_day  = p.expiry_date - days # Date
                    alert_time = tz.local(alert_day.year, alert_day.month, alert_day.day, 9, 0, 0)

                    # Absolute trigger; serialize as local time with TZID to avoid DST/UTC surprises
                    a.trigger = Icalendar::Values::DateTime.new(alert_time, "TZID" => "America/New_York")
                end
            end

          end
        end
      
        headers["Content-Type"]        = "text/calendar; charset=UTF-8"
        headers["Content-Disposition"] = 'attachment; filename="warranty_buddy.ics"'
        render plain: cal.to_ical
      end
      
end
  