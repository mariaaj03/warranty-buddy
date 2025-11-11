require "google/apis/calendar_v3"
require "googleauth"

class GoogleCalendarService
  def initialize(user)
    @user = user
    @service = Google::Apis::CalendarV3::CalendarService.new
    setup_authorization
  end

  def export_warranties(products, reminder_days: [])
    return { success: false, error: "Not authenticated" } unless @user.gmail_token.present?

    unless @service.authorization
      return { success: false, error: "Failed to authenticate with Google Calendar. Please sign out and sign in again to grant calendar permissions." }
    end

    begin
      created_count = 0
      errors = []

      products.each do |product|
        next unless product.expiry_date

        begin
          event = create_event_for_product(product, reminder_days)
          created_event = @service.insert_event("primary", event)
          created_count += 1
          Rails.logger.info "Created calendar event for #{product.product_name}: #{created_event.id}"
        rescue => e
          error_msg = e.message
          if error_msg.include?("insufficient authentication scopes") || error_msg.include?("Request had insufficient authentication scopes")
            error_msg = "Calendar permissions not granted. Please sign out and sign in again."
          end
          Rails.logger.error "Failed to create event for #{product.product_name}: #{error_msg}"
          Rails.logger.error e.backtrace.join("\n")
          errors << "#{product.product_name}: #{error_msg}"
        end
      end

      {
        success: true,
        created: created_count,
        errors: errors
      }
    rescue => e
      Rails.logger.error "Calendar export failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, error: e.message }
    end
  end

  private

  def setup_authorization
    return unless @user.gmail_token.present?

    begin
      client_id = Rails.application.credentials.dig(:google, :client_id) || ENV["GOOGLE_CLIENT_ID"]
      client_secret = Rails.application.credentials.dig(:google, :client_secret) || ENV["GOOGLE_CLIENT_SECRET"]

      return unless client_id.present? && client_secret.present?

      credentials = Google::Auth::UserRefreshCredentials.new(
        client_id: client_id,
        client_secret: client_secret,
        refresh_token: @user.gmail_refresh_token,
        access_token: @user.gmail_token
      )

      if credentials.expired? || credentials.expires_at.nil? || (credentials.expires_at && credentials.expires_at < Time.now)
        credentials.refresh!
        @user.update(
          gmail_token: credentials.access_token,
          gmail_refresh_token: credentials.refresh_token || @user.gmail_refresh_token
        )
      end

      @service.authorization = credentials
    rescue => e
      Rails.logger.error "Failed to setup calendar authorization: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      @service.authorization = nil
    end
  end

  def create_event_for_product(product, reminder_days)
    event = Google::Apis::CalendarV3::Event.new(
      summary: "Warranty expires: #{product.product_name}",
      description: build_description(product),
      start: Google::Apis::CalendarV3::EventDateTime.new(
        date: product.expiry_date.strftime("%Y-%m-%d"),
        time_zone: "America/New_York"
      ),
      end: Google::Apis::CalendarV3::EventDateTime.new(
        date: (product.expiry_date + 1.day).strftime("%Y-%m-%d"),
        time_zone: "America/New_York"
      ),
      reminders: Google::Apis::CalendarV3::Event::Reminders.new(
        use_default: false,
        overrides: build_reminders(product, reminder_days)
      )
    )

    event
  end

  def build_description(product)
    desc = "Warranty expiration reminder\n\n"
    desc += "Product: #{product.product_name}\n"
    desc += "Merchant: #{product.merchant}\n" if product.merchant.present?
    desc += "Purchase Date: #{product.purchase_date}\n" if product.purchase_date
    desc += "Warranty Length: #{product.warranty_months} month(s)\n" if product.warranty_months
    desc += "Status: #{product.status}\n" if product.respond_to?(:status)
    desc
  end

  def build_reminders(product, reminder_days)
    reminders = []
    
    if reminder_days.include?(0)
      reminders << Google::Apis::CalendarV3::EventReminder.new(
        method: "email",
        minutes: 0
      )
    end

    reminder_days.select { |d| d > 0 }.each do |days|
      minutes_before = days * 24 * 60
      reminders << Google::Apis::CalendarV3::EventReminder.new(
        method: "email",
        minutes: minutes_before
      )
    end

    reminders
  end
end

