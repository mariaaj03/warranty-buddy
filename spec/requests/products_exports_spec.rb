# frozen_string_literal: true
require 'rails_helper'

RSpec.describe "Products exports", type: :request do
  # Helper to stub session in request specs
  before do
    allow_any_instance_of(ActionDispatch::Request)
      .to receive(:session)
      .and_return({ gmail_uid: "demo_uid" })
  end

  describe "GET /products/export.csv" do
    it "returns CSV with headers and rows" do
      create(:product, gmail_uid: "demo_uid", product_name: "Thing 1")
      create(:product, gmail_uid: "demo_uid", product_name: "Thing 2")

      get export_products_path(format: :csv)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/csv")
      expect(response.headers["Content-Disposition"]).to include('attachment')
      # crude checks that usually hold for your export
      expect(response.body).to match(/Thing 1|Thing 2/)
    end
  end

  describe "GET /products/calendar (iCal)" do
    let!(:p1) { create(:product, gmail_uid: "demo_uid", product_name: "Alpha", expiry_date: Date.new(2025, 1, 10)) }
    let!(:p2) { create(:product, gmail_uid: "demo_uid", product_name: "Beta",  expiry_date: nil) } # hits the "next unless expiry_date" branch

    it "downloads ICS without reminders when none passed" do
      get calendar_products_path

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/calendar")
      expect(response.headers["Content-Disposition"]).to include('warranty_buddy.ics')
      body = response.body
      expect(body).to include("BEGIN:VCALENDAR", "BEGIN:VEVENT")
      # No TRIGGERs if no reminders
      expect(body).not_to include("TRIGGER")
      # Beta had nil expiry_date → only one VEVENT expected
      expect(body.scan("BEGIN:VEVENT").size).to eq(1)
      expect(body).to include("SUMMARY:Warranty expires: Alpha")
    end

    it "adds absolute TRIGGERs for same-day and 7/30 days" do
      get calendar_products_path, params: { reminders: %w[0 7 30] }

      body = response.body
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/calendar")
      # Absolute TRIGGERs (Option B) should look like TZID lines
      expect(body).to include("TRIGGER;TZID=America/New_York:")
      # Contains three alarms for the one event
      expect(body.scan("BEGIN:VALARM").size).to eq(3)
      # Basic sanity on DTSTART/DTEND as all-day dates
      expect(body).to include("DTSTART;VALUE=DATE:20250110")
      expect(body).to include("DTEND;VALUE=DATE:20250111")
    end
  end

  describe "GET /products/calendar when not connected to Gmail" do
    it "redirects to root with alert" do
      allow_any_instance_of(ActionDispatch::Request)
        .to receive(:session).and_return({})  # no gmail_uid

      get calendar_products_path

      expect(response).to redirect_to(root_path)
      # If you set flash alert in controller, you can fetch it by following redirect
      follow_redirect!
      expect(response.body).to include("Please connect Gmail first.")
    end
  end
end
