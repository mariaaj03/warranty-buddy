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
                p.status  # uses your model’s status method
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
    
        cal = Icalendar::Calendar.new
        cal.x_wr_calname = "Warranty Buddy – Your Warranties"
        cal.prodid = "-//Warranty Buddy//Iteration 1//EN"
    
        # Warranty expiration events
        products.each do |p|
        next unless p.expiry_date
        cal.event do |e|
            e.dtstart     = p.expiry_date
            e.dtend       = p.expiry_date + 1.day
            e.summary     = "Warranty expires: #{p.product_name}"
            e.description = <<~DESC
            Merchant: #{p.merchant}
            Purchase date: #{p.purchase_date}
            Warranty: #{p.warranty_months} month(s)
            Status: #{p.status}
            DESC
            e.uid         = "warranty-expiry-#{p.id}@warranty-buddy"
            e.transp      = "TRANSPARENT"
        end
        end
    
        # (Optional) Return deadline events, if you have them
        products.each do |p|
        next unless p.respond_to?(:return_deadline) && p.return_deadline
        cal.event do |e|
            e.dtstart     = p.return_deadline
            e.dtend       = p.return_deadline + 1.day
            e.summary     = "Return deadline: #{p.product_name}"
            e.description = "Merchant: #{p.merchant}"
            e.uid         = "return-deadline-#{p.id}@warranty-buddy"
            e.transp      = "TRANSPARENT"
        end
        end
    
        # Serve .ics
        headers["Content-Type"]        = "text/calendar; charset=UTF-8"
        headers["Content-Disposition"] = 'attachment; filename="warranty_buddy.ics"'
        render plain: cal.to_ical
    end
    
end
  