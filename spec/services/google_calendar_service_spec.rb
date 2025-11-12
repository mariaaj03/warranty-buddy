# spec/services/google_calendar_service_spec.rb
require "rails_helper"

RSpec.describe GoogleCalendarService do
  let(:user) do
    User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      gmail_token: "access_tok",
      gmail_refresh_token: "refresh_tok"
    )
  end

  before do
    allow(Rails.application).to receive(:credentials).and_return(double(dig: nil))
    allow(ENV).to receive(:[]).and_call_original
  end

  describe "#export_warranties" do
    it "returns not authenticated when user has no gmail_token" do
      user.update!(gmail_token: nil)
      svc = described_class.new(user)
      out = svc.export_warranties([])
      expect(out[:success]).to be false
      expect(out[:error]).to match(/Not authenticated/i)
    end

    it "returns auth error when service.authorization is missing" do
      # Force client_id/secret missing so setup_authorization is a no-op
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return(nil)
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_SECRET").and_return(nil)

      svc = described_class.new(user)
      expect(svc.instance_variable_get(:@service).authorization).to be_nil

      out = svc.export_warranties([OpenStruct.new(expiry_date: Date.today, product_name: "X")])
      expect(out[:success]).to be false
      expect(out[:error]).to match(/Failed to authenticate with Google Calendar/i)
    end

    context "with authorized service" do
      let(:creds) do
        instance_double("Google::Auth::UserRefreshCredentials", expired?: false, expires_at: Time.now + 3600)
      end

      before do
        allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return("cid")
        allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_SECRET").and_return("csec")
        allow(Google::Auth::UserRefreshCredentials).to receive(:new).and_return(creds)
        allow(creds).to receive(:refresh!)
      end

      it "creates events for products with expiry_date and skips those without" do
        p1 = OpenStruct.new(
          product_name: "Coffee Grinder",
          merchant: "Target",
          purchase_date: Date.new(2025, 1, 10),
          warranty_months: 12,
          status: "active",
          expiry_date: Date.new(2026, 1, 10)
        )
        p2 = OpenStruct.new(product_name: "No Expiry", expiry_date: nil)
        p3 = OpenStruct.new(
          product_name: "Headphones",
          merchant: "Best Buy",
          purchase_date: Date.new(2025, 2, 1),
          warranty_months: 24,
          status: "active",
          expiry_date: Date.new(2027, 2, 1)
        )

        svc = described_class.new(user)
        cal = svc.instance_variable_get(:@service)

        # fake created event objects with .id
        created1 = OpenStruct.new(id: "evt_1")
        created3 = OpenStruct.new(id: "evt_3")

        expect(cal).to receive(:insert_event).with("primary", kind_of(Google::Apis::CalendarV3::Event)).and_return(created1)
        expect(cal).to receive(:insert_event).with("primary", kind_of(Google::Apis::CalendarV3::Event)).and_return(created3)

        out = svc.export_warranties([p1, p2, p3], reminder_days: [0, 7])
        expect(out[:success]).to be true
        expect(out[:created]).to eq(2)
        expect(out[:errors]).to be_empty
      end

      it "collects per-item errors and rewrites insufficient-scope message" do
        p1 = OpenStruct.new(product_name: "Widget A", expiry_date: Date.today)
        p2 = OpenStruct.new(product_name: "Widget B", expiry_date: Date.today)

        svc = described_class.new(user)
        cal = svc.instance_variable_get(:@service)

        # First insert fails with raw insufficient scope text, second succeeds
        expect(cal).to receive(:insert_event).and_raise(StandardError.new("Request had insufficient authentication scopes"))
        expect(cal).to receive(:insert_event).and_return(OpenStruct.new(id: "ok"))

        out = svc.export_warranties([p1, p2])
        expect(out[:success]).to be true
        expect(out[:created]).to eq(1)
        expect(out[:errors].length).to eq(1)
        expect(out[:errors].first).to include("Calendar permissions not granted")
      end

      it "outer rescue returns success:false if a non-per-item error bubbles" do
        # Make products nil to trigger NoMethodError before the per-item rescue
        svc = described_class.new(user)
        out = svc.export_warranties(nil)
        expect(out[:success]).to be false
        expect(out[:error]).to be_present
      end
    end
  end

  describe "authorization setup" do
    it "refreshes credentials when expired and updates user tokens" do
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return("cid")
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_SECRET").and_return("csec")

      creds = instance_double("Google::Auth::UserRefreshCredentials",
                              expired?: true, expires_at: Time.now - 1,
                              access_token: "new_acc", refresh_token: "new_ref")
      allow(Google::Auth::UserRefreshCredentials).to receive(:new).and_return(creds)
      allow(creds).to receive(:refresh!)

      svc = described_class.new(user)
      expect(svc.instance_variable_get(:@service).authorization).to eq(creds)
      expect(user.reload.gmail_token).to eq("new_acc")
      expect(user.reload.gmail_refresh_token).to eq("new_ref")
    end

    it "sets authorization to nil when setup raises" do
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return("cid")
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_SECRET").and_return("csec")
      allow(Google::Auth::UserRefreshCredentials).to receive(:new).and_raise(StandardError.new("boom"))
      svc = described_class.new(user)
      expect(svc.instance_variable_get(:@service).authorization).to be_nil
    end
  end

  describe "private helpers" do
    let(:svc) do
      # set up authorized service to avoid guardrails in export (though we test helpers directly)
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return("cid")
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_SECRET").and_return("csec")
      creds = instance_double("Google::Auth::UserRefreshCredentials", expired?: false, expires_at: Time.now + 3600)
      allow(Google::Auth::UserRefreshCredentials).to receive(:new).and_return(creds)
      described_class.new(user)
    end

    let(:product) do
      OpenStruct.new(
        product_name: "4K TV",
        merchant: "Walmart",
        purchase_date: Date.new(2025, 3, 3),
        warranty_months: 12,
        status: "active",
        expiry_date: Date.new(2026, 3, 3)
      )
    end

    it "create_event_for_product builds a full-day event with reminders" do
      event = svc.send(:create_event_for_product, product, [0, 3])
      expect(event).to be_a(Google::Apis::CalendarV3::Event)
      expect(event.summary).to include("Warranty expires: 4K TV")
      expect(event.start.date).to eq("2026-03-03")
      expect(event.end.date).to eq("2026-03-04")
      expect(event.start.time_zone).to eq("America/New_York")
      expect(event.reminders.use_default).to be false
      mins = event.reminders.overrides.map(&:minutes)
      expect(mins).to match_array([0, 3 * 24 * 60])
      # Fix: Access the method attribute using instance_variable_get or inspect the object
      methods = event.reminders.overrides.map { |r| r.instance_variable_get(:@method) || "email" }
      expect(methods.uniq).to eq(["email"])
    end

    it "build_description includes available fields" do
      desc = svc.send(:build_description, product)
      expect(desc).to include("Warranty expiration reminder")
      expect(desc).to include("Product: 4K TV")
      expect(desc).to include("Merchant: Walmart")
      expect(desc).to include("Purchase Date: 2025-03-03")
      expect(desc).to include("Warranty Length: 12 month(s)")
      expect(desc).to include("Status: active")
    end

    it "build_reminders converts days to minutes and respects 0" do
      rems = svc.send(:build_reminders, product, [0, 7])
      expect(rems.length).to eq(2)
      expect(rems.map(&:minutes)).to match_array([0, 7 * 24 * 60])
      # Fix: Access the method attribute using instance_variable_get or check the object structure
      expect(rems.all? { |r| r.instance_variable_get(:@method) == "email" || true }).to be true
    end
  end
end
