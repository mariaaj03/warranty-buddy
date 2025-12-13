# spec/services/google_vision_service_spec.rb
require "rails_helper"
require "ostruct"

RSpec.describe GoogleVisionService do
  let(:user) do
    User.create!(
      email: "t@example.com",
      password: "password123",
      password_confirmation: "password123",
      gmail_token: "acc_tok",
      gmail_refresh_token: "ref_tok"
    )
  end

  before do
    # Default: no creds in credentials; we’ll stub per example
    allow(Rails.application).to receive(:credentials).and_return(double(dig: nil))
    allow(ENV).to receive(:[]).and_call_original
  end

  def http_double_sequence(*responses)
    http = instance_double("Net::HTTP")
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:verify_mode=) # not used in test env, but safe
    allow(http).to receive(:request).and_return(*responses)
  end

  describe "setup_authorization" do
    it "API key present → does not configure OAuth; uses API-key mode later" do
      allow(ENV).to receive(:[]).with("GOOGLE_VISION_API_KEY").and_return("VISION_KEY")
      svc = described_class.new(nil, nil)
      # Authorization should remain nil; API calls will go through HTTP path
      expect(svc.instance_variable_get(:@service).authorization).to be_nil
    end

    it "OAuth path with user tokens, no refresh needed" do
      allow(ENV).to receive(:[]).with("GOOGLE_VISION_API_KEY").and_return(nil)
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return("cid")
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_SECRET").and_return("csec")

      creds = instance_double("Google::Auth::UserRefreshCredentials",
                              expired?: false, expires_at: Time.now + 3600)
      allow(Google::Auth::UserRefreshCredentials).to receive(:new).and_return(creds)
      allow(creds).to receive(:refresh!)

      svc = described_class.new(nil, user)
      expect(Google::Auth::UserRefreshCredentials).to have_received(:new).with(
        hash_including(client_id: "cid", client_secret: "csec",
                       refresh_token: "ref_tok", access_token: "acc_tok",
                       scope: "https://www.googleapis.com/auth/cloud-vision")
      )
      expect(svc.instance_variable_get(:@service).authorization).to eq(creds)
      expect(creds).not_to have_received(:refresh!)
    end

    it "OAuth path refreshes when expired and updates user tokens" do
      allow(ENV).to receive(:[]).with("GOOGLE_VISION_API_KEY").and_return(nil)
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return("cid")
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_SECRET").and_return("csec")

      creds = instance_double("Google::Auth::UserRefreshCredentials",
                              expired?: true, expires_at: Time.now - 1,
                              access_token: "new_acc", refresh_token: "new_ref")
      allow(Google::Auth::UserRefreshCredentials).to receive(:new).and_return(creds)
      allow(creds).to receive(:refresh!)

      described_class.new(nil, user)
      expect(user.reload.gmail_token).to eq("new_acc")
      expect(user.reload.gmail_refresh_token).to eq("new_ref")
    end

  end

  describe "#extract_text_from_image" do
    context "API key mode (REST)" do
      before do
        allow(ENV).to receive(:[]).with("GOOGLE_VISION_API_KEY").and_return("VISION_KEY")
      end

      it "returns text when HTTP 200 and textAnnotations present" do
        body = {
          responses: [
            { textAnnotations: [{ "description" => "Detected text\nMore" }] }
          ]
        }.to_json
        resp = instance_double("Net::HTTPOK", code: "200", body: body)
        http_double_sequence(resp)

        svc = described_class.new(nil, nil)
        out = svc.extract_text_from_image("IMGDATA")
        expect(out).to include("Detected text")
      end

      it "returns empty string when 200 but no annotations" do
        resp = instance_double("Net::HTTPOK", code: "200", body: { responses: [ {} ] }.to_json)
        http_double_sequence(resp)
        svc = described_class.new(nil, nil)
        expect(svc.extract_text_from_image("IMG")).to eq("")
      end

      it "returns nil on non-200" do
        resp = instance_double("Net::HTTPUnauthorized", code: "401", body: '{"error":"nope"}')
        http_double_sequence(resp)
        svc = described_class.new(nil, nil)
        expect(svc.extract_text_from_image("IMG")).to be_nil
      end

      it "rescues and returns nil on exceptions" do
        allow(Net::HTTP).to receive(:new).and_raise(StandardError.new("boom"))
        svc = described_class.new(nil, nil)
        expect(svc.extract_text_from_image("IMG")).to be_nil
      end
    end

    context "OAuth / client library path" do
      let(:svc) do
        allow(ENV).to receive(:[]).with("GOOGLE_VISION_API_KEY").and_return(nil)
        allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return("cid")
        allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_SECRET").and_return("csec")

        creds = instance_double("Google::Auth::UserRefreshCredentials",
                                expired?: false, expires_at: Time.now + 3600)
        allow(Google::Auth::UserRefreshCredentials).to receive(:new).and_return(creds)
        described_class.new(nil, user)
      end

      it "calls annotate_image and returns description" do
        # Minimal fake annotate response
        annot = OpenStruct.new(description: "Hello OCR")
        resp  = OpenStruct.new(text_annotations: [annot])
        service = svc.instance_variable_get(:@service)
        expect(service).to receive(:annotate_image).and_return(resp)

        out = svc.extract_text_from_image("IMGDATA")
        expect(out).to eq("Hello OCR")
      end

      it "returns '' when no text_annotations" do
        service = svc.instance_variable_get(:@service)
        expect(service).to receive(:annotate_image).and_return(OpenStruct.new(text_annotations: []))
        expect(svc.extract_text_from_image("IMG")).to eq("")
      end

      it "rescues and returns nil on error" do
        service = svc.instance_variable_get(:@service)
        expect(service).to receive(:annotate_image).and_raise(StandardError.new("bad"))
        expect(svc.extract_text_from_image("IMG")).to be_nil
      end
    end

    it "returns nil and logs when neither API key nor authorization set" do
      # No API key, no OAuth creds, no service account
      allow(ENV).to receive(:[]).with("GOOGLE_VISION_API_KEY").and_return(nil)
      allow(Rails.application).to receive(:credentials).and_return(double(dig: nil))
      gvs = described_class.new(nil, nil)
      # manually clear any authorization (should be nil already)
      gvs.instance_variable_get(:@service).authorization = nil
      expect(gvs.extract_text_from_image("IMG")).to be_nil
    end
  end

  describe "#extract_text_from_pdf" do
    let(:pdf_bytes) { "%PDF-1.4 ...".b } # dummy

    it "reads pages with PDF::Reader and concatenates text" do
      svc = described_class.new("KEY", nil)

      # Stub require "pdf-reader" to succeed
      allow(svc).to receive(:require).with("pdf-reader").and_return(true)

      page1 = double(text: "First page")
      page2 = double(text: "Second page")
      reader = double(pages: [page1, page2])
      allow(PDF::Reader).to receive(:new).and_return(reader)

      out = svc.extract_text_from_pdf(pdf_bytes)
      expect(out).to include("First page")
      expect(out).to include("Second page")
    end

    it "returns nil if pdf-reader gem is missing" do
      svc = described_class.new("KEY", nil)
      allow(svc).to receive(:require).with("pdf-reader").and_raise(LoadError)
      expect(svc.extract_text_from_pdf(pdf_bytes)).to be_nil
    end

    it "returns nil on generic error" do
      svc = described_class.new("KEY", nil)
      allow(svc).to receive(:require).with("pdf-reader").and_return(true)
      allow(PDF::Reader).to receive(:new).and_raise(StandardError.new("boom"))
      expect(svc.extract_text_from_pdf(pdf_bytes)).to be_nil
    end
  end
end
