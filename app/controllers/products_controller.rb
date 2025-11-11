class ProductsController < ApplicationController
  before_action :authenticate_user!
  require "csv"

  def export
    products = current_user.products.to_a.sort_by do |p|
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
    require "icalendar"

    products = current_user.products.to_a

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

                    alert_day  = p.expiry_date - days
                    alert_time = tz.local(alert_day.year, alert_day.month, alert_day.day, 9, 0, 0)

                    a.trigger = Icalendar::Values::DateTime.new(alert_time, "TZID" => "America/New_York")
                end
            end
          end
        end

        headers["Content-Type"]        = "text/calendar; charset=UTF-8"
        headers["Content-Disposition"] = 'attachment; filename="warranty_buddy.ics"'
        render plain: cal.to_ical
      end

  def export_to_google_calendar
    unless current_user.gmail_connected?
      redirect_to dashboard_path, alert: "Please connect your Google account first"
      return
    end

    products = current_user.products.to_a.select { |p| p.expiry_date.present? }

    if products.empty?
      redirect_to dashboard_path, alert: "No warranties with expiry dates found"
      return
    end

    reminder_days = Array(params[:reminders])
                      .map { |s| Integer(s) rescue nil }
                      .compact
                      .select { |n| n >= 0 }
                      .uniq
                      .sort

    calendar_service = GoogleCalendarService.new(current_user)
    result = calendar_service.export_warranties(products, reminder_days: reminder_days)

    if result[:success]
      if result[:errors].any?
        redirect_to dashboard_path, notice: "Exported #{result[:created]} warranty(ies) to Google Calendar. #{result[:errors].length} error(s) occurred."
      else
        redirect_to dashboard_path, notice: "Successfully exported #{result[:created]} warranty(ies) to Google Calendar!"
      end
    else
      redirect_to dashboard_path, alert: "Failed to export to Google Calendar: #{result[:error]}"
    end
  end
end
