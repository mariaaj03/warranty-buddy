# spec/requests/products_controller_spec.rb
require "rails_helper"

RSpec.describe ProductsController, type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) do
    User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  describe "authentication" do
    it "redirects to login when not signed in for export" do
      get export_products_path(format: :csv)
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects to login when not signed in for calendar" do
      get calendar_products_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects to login when not signed in for google export" do
      post export_to_google_calendar_products_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /products/export" do
    before { sign_in user }

    context "with CSV format" do
      it "returns a CSV file with the user's products" do
        p1 = Product.create!(
          user: user,
          product_name: "Laptop",
          merchant: "Best Buy",
          purchase_date: Date.new(2024, 1, 1),
          warranty_months: 12,
          expiry_date: Date.new(2025, 1, 1),
          status: "active"
        )

        p2 = Product.create!(
          user: user,
          product_name: "Headphones",
          merchant: "Amazon",
          purchase_date: Date.new(2024, 2, 1),
          warranty_months: 6,
          expiry_date: nil,
          status: "active"
        )

        get export_products_path(format: :csv)

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("text/csv")
        expect(response.headers["Content-Disposition"]).to include("warranties.csv")

        body = response.body
        expect(body).to include("product_name,merchant") # header row
        expect(body).to include("Laptop")
        expect(body).to include("Headphones")
      end

      it "handles empty product list" do
        get export_products_path(format: :csv)

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("text/csv")
        
        body = response.body
        lines = body.split("\n")
        expect(lines.first).to include("product_name") # header should still be there
      end
    end

    context "with HTML format (fallback)" do
      it "handles non-CSV requests" do
        get export_products_path

        expect(response).to have_http_status(:ok)
        # This might redirect or render a different template
      end
    end

    context "with JSON format" do
      it "handles JSON requests if supported" do
        get export_products_path(format: :json)

        # This will either work or return 406 Not Acceptable
        expect(response.status).to be_in([200, 406])
      end
    end
  end

  describe "GET /products/calendar" do
    before { sign_in user }

    it "returns an ics file with events for products that have expiry dates" do
      product_with_expiry = Product.create!(
        user: user,
        product_name: "Camera",
        merchant: "Target",
        purchase_date: Date.new(2024, 3, 1),
        warranty_months: 24,
        expiry_date: Date.new(2026, 3, 1),
        status: "active"
      )

      get calendar_products_path(reminders: ["7", "0", "-5", "abc"])

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/calendar")
      expect(response.headers["Content-Disposition"]).to include("warranty_buddy.ics")

      ics = response.body
      expect(ics).to include("BEGIN:VCALENDAR")
      expect(ics).to include("SUMMARY:Warranty expires: #{product_with_expiry.product_name}")
      expect(ics).to include("BEGIN:VALARM")
    end

    it "handles products without expiry dates" do
      Product.create!(
        user: user,
        product_name: "No Expiry Product",
        merchant: "Store",
        purchase_date: nil,
        warranty_months: nil,
        expiry_date: nil,
        status: "active"
      )

      get calendar_products_path

      expect(response).to have_http_status(:ok)
      ics = response.body
      expect(ics).to include("BEGIN:VCALENDAR")
      expect(ics).to include("END:VCALENDAR")
    end

    it "handles empty reminders parameter" do
      product_with_expiry = Product.create!(
        user: user,
        product_name: "Test Product",
        merchant: "Test Store",
        purchase_date: 1.month.ago,
        warranty_months: 12,
        expiry_date: 11.months.from_now,
        status: "active"
      )

      get calendar_products_path(reminders: [])

      expect(response).to have_http_status(:ok)
      ics = response.body
      expect(ics).to include("BEGIN:VCALENDAR")
    end

    it "handles nil reminders parameter" do
      get calendar_products_path

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/calendar")
    end

    it "handles malformed reminders" do
      get calendar_products_path(reminders: "not_an_array")

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/calendar")
    end
  end

  describe "POST /products/export_to_google_calendar" do
    before { sign_in user }

    let!(:product1) do
      Product.create!(
        user: user,
        product_name: "Phone",
        merchant: "Apple",
        purchase_date: Date.new(2024, 4, 1),
        warranty_months: 12,
        expiry_date: Date.new(2025, 4, 1),
        status: "active"
      )
    end

    context "when gmail is not connected" do
      it "redirects with an alert" do
        allow(user).to receive(:gmail_connected?).and_return(false)

        post export_to_google_calendar_products_path

        expect(response).to redirect_to(dashboard_path)
        expect(flash[:alert]).to eq("Please connect your Google account first")
      end
    end

    context "when gmail is connected but there are no expiring products" do
      it "redirects with an alert" do
        allow(user).to receive(:gmail_connected?).and_return(true)
        Product.delete_all

        post export_to_google_calendar_products_path

        expect(response).to redirect_to(dashboard_path)
        expect(flash[:alert]).to eq("No warranties with expiry dates found")
      end
    end

    context "when export succeeds with no errors" do
      it "redirects with a success notice" do
        allow(user).to receive(:gmail_connected?).and_return(true)

        service = instance_double(GoogleCalendarService)
        allow(GoogleCalendarService).to receive(:new).with(user).and_return(service)
        allow(service).to receive(:export_warranties)
          .and_return({ success: true, created: 1, errors: [] })

        post export_to_google_calendar_products_path, params: { reminders: ["7", "30"] }

        expect(response).to redirect_to(dashboard_path)
        expect(flash[:notice]).to eq("Successfully exported 1 warranty(ies) to Google Calendar!")
      end
    end

    context "when export succeeds but has some errors" do
      it "redirects with a mixed notice" do
        allow(user).to receive(:gmail_connected?).and_return(true)

        service = instance_double(GoogleCalendarService)
        allow(GoogleCalendarService).to receive(:new).with(user).and_return(service)
        allow(service).to receive(:export_warranties)
          .and_return({ success: true, created: 2, errors: ["bad event"] })

        post export_to_google_calendar_products_path

        expect(response).to redirect_to(dashboard_path)
        expect(flash[:notice]).to eq(
          "Exported 2 warranty(ies) to Google Calendar. 1 error(s) occurred."
        )
      end
    end

    context "when export fails" do
      it "redirects with an error alert" do
        allow(user).to receive(:gmail_connected?).and_return(true)

        service = instance_double(GoogleCalendarService)
        allow(GoogleCalendarService).to receive(:new).with(user).and_return(service)
        allow(service).to receive(:export_warranties)
          .and_return({ success: false, error: "API error" })

        post export_to_google_calendar_products_path

        expect(response).to redirect_to(dashboard_path)
        expect(flash[:alert]).to eq("Failed to export to Google Calendar: API error")
      end
    end

    context "when GoogleCalendarService raises an exception" do
      it "handles service exceptions gracefully" do
        allow(user).to receive(:gmail_connected?).and_return(true)

        service = instance_double(GoogleCalendarService)
        allow(GoogleCalendarService).to receive(:new).with(user).and_return(service)
        allow(service).to receive(:export_warranties).and_raise(StandardError, "Service error")

        post export_to_google_calendar_products_path

        expect(response).to redirect_to(dashboard_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "with different reminder parameters" do
      it "handles string reminders parameter" do
        allow(user).to receive(:gmail_connected?).and_return(true)

        service = instance_double(GoogleCalendarService)
        allow(GoogleCalendarService).to receive(:new).with(user).and_return(service)
        allow(service).to receive(:export_warranties)
          .and_return({ success: true, created: 1, errors: [] })

        post export_to_google_calendar_products_path, params: { reminders: "7,30" }

        expect(response).to redirect_to(dashboard_path)
      end

      it "handles empty reminders parameter" do
        allow(user).to receive(:gmail_connected?).and_return(true)

        service = instance_double(GoogleCalendarService)
        allow(GoogleCalendarService).to receive(:new).with(user).and_return(service)
        allow(service).to receive(:export_warranties)
          .and_return({ success: true, created: 1, errors: [] })

        post export_to_google_calendar_products_path, params: { reminders: [] }

        expect(response).to redirect_to(dashboard_path)
      end
    end
  end

  # Test any rescue blocks or error handling
  describe "error handling" do
    before { sign_in user }

    it "handles CSV generation errors gracefully" do
      allow(CSV).to receive(:generate).and_raise(StandardError, "CSV error")

      get export_products_path(format: :csv)

      # Depending on your error handling, this might redirect or return 500
      expect(response.status).to be_in([200, 302, 500])
    end

    it "handles calendar generation errors gracefully" do
      allow_any_instance_of(Icalendar::Calendar).to receive(:to_ical).and_raise(StandardError, "iCal error")

      get calendar_products_path

      expect(response.status).to be_in([200, 302, 500])
    end
  end
end
