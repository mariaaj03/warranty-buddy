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

  let(:service_double) { instance_double(Google::Apis::CalendarV3::CalendarService, authorization: nil) }

  before do
    # Stub the Google Calendar service instance created in initialize
    allow(Google::Apis::CalendarV3::CalendarService).to receive(:new).and_return(service_double)
    # Default: no creds set unless a test wires them
    allow(Rails.application.credentials).to receive(:dig).and_return(nil)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return(nil)
    allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_SECRET").and_return(nil)
  end

  def make_product(attrs = {})
    Product.create!(
      { user: user, product_name: "Item", merchant: "Shop",
        purchase_date: Date.new(2024,1,1), warranty_months: 12,
        expiry_date: Date.new(2025,1,1), status: "active" }.merge(attrs)
    )
  end

  describe "#export_warranties" do
    it "returns Not authenticated when gmail_token is missing" do
      user.update!(gmail_token: nil)

      result = described_class.new(user).export_warranties([make_product])
      expect(result[:success]).to eq(false)
      expect(result[:error]).to eq("Not authenticated")
    end

    it "returns error when service has no authorization (redirect user to re-grant)" do
      # leave creds unset so setup_authorization can't set authorization
      svc = described_class.new(user)
      expect(service_double.authorization).to be_nil

      result = svc.export_warranties([make_product])
      expect(result[:success]).to eq(false)
      expect(result[:error]).to match(/Failed to authenticate with Google Calendar/)
    end

    it "creates events (success path) and ignores products without expiry" do
      # Provide client credentials so setup_authorization runs
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return("cid")
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_SECRET").and_return("secret")

      # Stub credentials object used by setup_authorization
      creds = instance_double(Google::Auth::UserRefreshCredentials,
                              expired?: false, expires_at: Time.now + 3600,
                              access_token: "tok", refresh_token: "rtok")
      allow(Google::Auth::UserRefreshCredentials).to receive(:new).and_return(creds)

      # Allow the service to have authorization
      allow(service_double).to receive(:authorization=).with(creds) { |val| allow(service_double).to receive(:authorization).and_return(val) }

      # insert_event returns an object with id
      created = instance_double(Google::Apis::CalendarV3::Event, id: "abc123")
      allow(service_double).to receive(:insert_event).and_return(created)

      p_ok   = make_product
      p_skip = make_product(expiry_date: nil)

      result = described_class.new(user).export_warranties([p_ok, p_skip])
      expect(result[:success]).to eq(true)
      expect(result[:created]).to eq(1)
      expect(result[:errors]).to eq([])
      expect(service_double).to have_received(:insert_event).once
    end

    it "maps 'insufficient authentication scopes' to friendly error" do
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return("cid")
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_SECRET").and_return("secret")
      creds = instance_double(Google::Auth::UserRefreshCredentials,
                              expired?: false, expires_at: Time.now + 3600,
                              access_token: "tok", refresh_token: "rtok")
      allow(Google::Auth::UserRefreshCredentials).to receive(:new).and_return(creds)
      allow(service_double).to receive(:authorization=).with(creds) { |val| allow(service_double).to receive(:authorization).and_return(val) }

      allow(service_double).to receive(:insert_event)
        .and_raise(StandardError.new("Request had insufficient authentication scopes"))

      p1 = make_product(product_name: "Camera")
      result = described_class.new(user).export_warranties([p1])

      expect(result[:success]).to eq(true)
      expect(result[:created]).to eq(0)
      expect(result[:errors].first).to include("Camera:")
      expect(result[:errors].first).to include("Calendar permissions not granted")
    end
  end

  describe "token refresh during setup_authorization" do
    it "refreshes expired creds and updates the user tokens" do
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return("cid")
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_SECRET").and_return("secret")

      creds = instance_double(Google::Auth::UserRefreshCredentials,
                              expired?: true, expires_at: Time.now - 60,
                              access_token: "old", refresh_token: "old_r")
      allow(Google::Auth::UserRefreshCredentials).to receive(:new).and_return(creds)

      # When refreshed, return new tokens
      allow(creds).to receive(:refresh!) do
        allow(creds).to receive(:access_token).and_return("new_tok")
        allow(creds).to receive(:refresh_token).and_return("new_rt")
      end

      allow(service_double).to receive(:authorization=)

      described_class.new(user) # triggers setup_authorization
      user.reload
      expect(user.gmail_token).to eq("new_tok")
      expect(user.gmail_refresh_token).to eq("new_rt")
    end
  end
end
