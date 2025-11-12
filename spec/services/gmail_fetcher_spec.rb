# spec/services/gmail_fetcher_spec.rb
require "rails_helper"
require "ostruct"
require "base64"

RSpec.describe GmailFetcher do
  Gmail = Google::Apis::GmailV1

  # Minimal fake "user" for token update checks
  let(:user) do
    User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      gmail_token: "old_access",
      gmail_refresh_token: "old_refresh"
    )
  end

  # Helper builders for Gmail API structures (using OpenStruct to avoid hard deps)
  def msg(id:, payload:)
    OpenStruct.new(id: id, payload: payload)
  end

  def part(mime_type:, body: nil, parts: nil, filename: nil)
    OpenStruct.new(mime_type: mime_type, body: body, parts: parts, filename: filename)
  end

  def body(data: nil, attachment_id: nil)
    OpenStruct.new(data: data, attachment_id: attachment_id)
  end

  def list_messages_response(messages:, next_page_token: nil)
    OpenStruct.new(messages: messages, next_page_token: next_page_token)
  end

  describe "initialize / setup_authorization_with_refresh" do
    before do
      # Default credentials to satisfy dig calls
      allow(Rails.application).to receive(:credentials)
        .and_return(double(dig: nil))
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return("cid")
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_SECRET").and_return("csec")
    end

    it "sets raw access_token when no refresh_token or user provided" do
      f = described_class.new("raw_token", nil, nil)
      expect(f.service.authorization).to eq("raw_token")
    end

    it "builds refresh credentials, refreshes if expired, and updates user tokens" do
      creds = instance_double("Google::Auth::UserRefreshCredentials",
        expired?: true, expires_at: Time.now - 3600,
        refresh!: nil, access_token: "new_access", refresh_token: "new_refresh"
      )
      allow(Google::Auth::UserRefreshCredentials).to receive(:new).and_return(creds)

      f = described_class.new("raw_access", "rtoken", user)
      expect(Google::Auth::UserRefreshCredentials).to have_received(:new).with(
        hash_including(
          client_id: "cid",
          client_secret: "csec",
          refresh_token: "rtoken",
          access_token: "raw_access"
        )
      )
      expect(user.reload.gmail_token).to eq("new_access")
      expect(user.reload.gmail_refresh_token).to eq("new_refresh")
      expect(f.service.authorization).to eq(creds)
    end

    it "does not refresh if not expired and sets credentials" do
      creds = instance_double("Google::Auth::UserRefreshCredentials",
        expired?: false, expires_at: Time.now + 3600
      )
      allow(creds).to receive(:refresh!)
      allow(Google::Auth::UserRefreshCredentials).to receive(:new).and_return(creds)

      f = described_class.new("raw_access", "rtoken", user)
      expect(creds).not_to have_received(:refresh!)
      expect(f.service.authorization).to eq(creds)
    end

    it "returns early if client_id/secret missing (keeps service.authorization = nil?)" do
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return(nil)
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_SECRET").and_return(nil)

      f = described_class.new("raw_access", "rtoken", user)
      # setup_authorization_with_refresh returns without setting creds
      # In this case service.authorization remains nil (not raw token),
      # because the code path only sets creds if client_id/secret are present.
      expect(f.service.authorization).to be_nil
    end
  end

  describe "#list_order_messages" do
    let(:fetcher) { described_class.new("tok") }
    let(:svc)     { fetcher.service }

    it "combines multiple query runs, de-duplicates, and respects max_results" do
      # Two queries -> stub list_user_messages twice (with pagination inside helper)
      m1 = OpenStruct.new(id: "A1")
      m2 = OpenStruct.new(id: "A2")
      m3 = OpenStruct.new(id: "A2") # duplicate id
      m4 = OpenStruct.new(id: "A3")

      # First query returns A1, A2
      allow(svc).to receive(:list_user_messages)
        .and_return(
          list_messages_response(messages: [m1, m2], next_page_token: nil),  # first query, page 1
          list_messages_response(messages: [m3, m4], next_page_token: nil)   # second query, page 1
        )

      out = fetcher.list_order_messages("me", 3)
      expect(out.map(&:id)).to eq(%w[A1 A2 A3]) # de-duped and capped to 3
    end
  end

  describe "delegations" do
    let(:fetcher) { described_class.new("tok") }
    let(:svc)     { fetcher.service }

    it "get_message delegates to service.get_user_message" do
      expect(svc).to receive(:get_user_message).with("me", "MID", format: "full").and_return(:ok)
      expect(fetcher.get_message("MID", "me")).to eq(:ok)
    end

    it "get_attachment delegates to service.get_user_message_attachment" do
      expect(svc).to receive(:get_user_message_attachment).with("me", "MID", "ATT").and_return(:blob)
      expect(fetcher.get_attachment("MID", "ATT", "me")).to eq(:blob)
    end
  end

  describe "content extraction" do
    let(:fetcher) { described_class.new("tok") }

    it "extracts HTML from top-level body if body contains html" do
      html = "<html><body>Hello</body></html>"
      encoded = Base64.urlsafe_encode64(html)
      message = msg(
        id: "1",
        payload: part(mime_type: "multipart/alternative", body: body(data: encoded))
      )
      expect(fetcher.extract_html_from_message(message)).to include("Hello")
      # since body has HTML, text extractor should ignore it and return ""
      expect(fetcher.extract_text_from_message(message)).to eq("")
    end

    it "falls back to parts traversal for HTML and text" do
      html = "<html><body>Hi from nested</body></html>"
      text = "Plain nested text"
      html_b64 = Base64.urlsafe_encode64(html)
      text_b64 = Base64.urlsafe_encode64(text)

      nested = part(
        mime_type: "multipart/mixed",
        parts: [
          part(mime_type: "text/plain", body: body(data: text_b64)),
          part(mime_type: "text/html",  body: body(data: html_b64))
        ]
      )
      top = part(mime_type: "multipart/alternative", parts: [nested])
      message = msg(id: "2", payload: top)

      expect(fetcher.extract_html_from_message(message)).to include("Hi from nested")
      expect(fetcher.extract_text_from_message(message)).to include("Plain nested text")
    end

    it "handles non-urlsafe base64 gracefully (falls back decode64)" do
      html = "<html><body>Legacy</body></html>"
      encoded_bad = Base64.encode64(html) # not urlsafe
      message = msg(
        id: "3",
        payload: part(mime_type: "text/html", body: body(data: encoded_bad))
      )
      expect(fetcher.extract_html_from_message(message)).to include("Legacy")
    end

    it "returns empty strings when nothing found" do
      message = msg(id: "4", payload: part(mime_type: "multipart/mixed", parts: []))
      expect(fetcher.extract_html_from_message(message)).to eq("")
      expect(fetcher.extract_text_from_message(message)).to eq("")
    end
  end

  describe "#extract_attachments" do
    let(:fetcher) { described_class.new("tok") }

    it "collects attachments from top-level and nested parts" do
      top_att = part(
        mime_type: "application/pdf",
        filename: "a.pdf",
        body: body(attachment_id: "att1")
      )
      nested_att = part(
        mime_type: "image/png",
        filename: "img.png",
        body: body(attachment_id: "att2")
      )
      nested = part(mime_type: "multipart/mixed", parts: [nested_att])
      payload = part(mime_type: "multipart/mixed", parts: [top_att, nested])
      message = msg(id: "m", payload: payload)

      out = fetcher.extract_attachments(message)
      expect(out).to contain_exactly(
        { filename: "a.pdf", attachment_id: "att1", mime_type: "application/pdf" },
        { filename: "img.png", attachment_id: "att2", mime_type: "image/png" }
      )
    end

    it "returns empty list when no parts" do
      message = msg(id: "m2", payload: OpenStruct.new(parts: nil))
      expect(fetcher.extract_attachments(message)).to eq([])
    end
  end
end
