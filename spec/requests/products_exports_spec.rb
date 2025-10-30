require 'rails_helper'

RSpec.describe "Products exports", type: :request do
    before do
        # Use a real test session object so Rails doesn't call `enabled?` on a Hash
        test_session = ActionController::TestSession.new(gmail_uid: "demo_uid")
        allow_any_instance_of(ActionDispatch::Request)
          .to receive(:session).and_return(test_session)
      end


  describe "GET /products/export.csv" do
    it "returns CSV with rows" do
      create(:product, gmail_uid: "demo_uid", product_name: "Thing 1")
      create(:product, gmail_uid: "demo_uid", product_name: "Thing 2")

      get export_products_path(format: :csv)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/csv")
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(response.body).to include("Thing 1").or include("Thing 2")
    end
  end

  describe "GET /products/calendar (iCal)" do
    # Product that WILL have an expiry (via purchase_date + warranty_months)
    let!(:p1) { create(:product, :expiring_soon, gmail_uid: "demo_uid", product_name: "Alpha") }

    # Product that WON'T (forces skip branch)
    let!(:p2) { create(:product, gmail_uid: "demo_uid", product_name: "Beta", warranty_months: nil) }

    it "downloads ICS with no alarms when no reminders passed" do
      get calendar_products_path
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/calendar")
      body = response.body
      expect(body).to include("BEGIN:VCALENDAR", "BEGIN:VEVENT")
      expect(body.scan("BEGIN:VEVENT").size).to eq(1) # Beta skipped
      expect(body).to include("SUMMARY:Warranty expires: Alpha")
      expect(body).not_to include("TRIGGER")
    end

    it "adds absolute TRIGGERs when reminders are provided" do
      get calendar_products_path, params: { reminders: %w[0 7 30] }
      body = response.body
      expect(response).to have_http_status(:ok)
      expect(body.scan("BEGIN:VALARM").size).to eq(3)
    trigger_regex = /
    TRIGGER              # field
    (?:;[^:\r\n]+)?
    :                    # colon
    (?:                  # value can be:
        \d{8}T\d{6}Z?     #   absolute datetime (UTC or local)
        | -P\d+D          #   duration N days before
        | PT0S            #   same-day zero offset
    )
    /x

    expect(body.scan(trigger_regex).length).to eq(3)
      expect(body).to include("DTSTART;VALUE=DATE:")
      expect(body).to include("DTEND;VALUE=DATE:")
    end
end


  it "redirects to root with an alert" do
    allow_any_instance_of(ActionDispatch::Request)
      .to receive(:session).and_return(ActionController::TestSession.new) # empty
    get calendar_products_path
    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include("Please connect Gmail first.")
  end
end
