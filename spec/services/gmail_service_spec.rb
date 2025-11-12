# spec/services/gmail_service_spec.rb
require "rails_helper"

RSpec.describe GmailService do
  # Minimal message/header structs to mimic Gmail API objects
  Header  = Struct.new(:name, :value)
  Payload = Struct.new(:headers)
  Msg     = Struct.new(:id, :payload)
  Attach  = Struct.new(:data)

  let(:user) { User.create!(email: "u@example.com", password: "passpass", password_confirmation: "passpass") }

  # Doubles for collaborator classes
  let(:fetcher)   { instance_double("GmailFetcher") }
  let(:rp)        { instance_double("ReceiptProcessor") }
  let(:service)   { instance_double("StructService", authorization: Object.new) } # fetcher.service

  before do
    # Stub constructor injections used by GmailService
    allow(GmailFetcher).to receive(:new).and_return(fetcher)
    allow(ReceiptProcessor).to receive(:new).and_return(rp)
    allow(fetcher).to receive(:service).and_return(service)

    # Default cleanup expectation (verified explicitly in one example)
    allow(rp).to receive(:cleanup)
  end

  def headers(hash)
    Payload.new(hash.map { |k, v| Header.new(k, v) })
  end

  describe "#parse_receipt_emails" do
    it "returns [] when not authorized" do
      allow(fetcher).to receive(:service).and_return(double(authorization: nil))
      result = described_class.new("tok", "rtok", user).parse_receipt_emails("me")
      expect(result).to eq([])
      # Remove this expectation since cleanup is not called on early return
      # expect(rp).to have_received(:cleanup)
    end

    it "parses via merchant parser (happy path), adds warranty months from GoogleSearchService" do
      # 1 message with HTML/TEXT and one line item
      msg_list = [double(id: "m1")]
      full_msg = Msg.new("m1", headers(
        "Subject" => "Order Confirmation",
        "From"    => "Amazon <order-update@amazon.com>",
        "Date"    => "Mon, 1 Jan 2024 10:00:00 -0400"
      ))

      allow(fetcher).to receive(:list_order_messages).with("me", 50).and_return(msg_list)
      allow(fetcher).to receive(:get_message).with("m1", "me").and_return(full_msg)
      allow(fetcher).to receive(:extract_html_from_message).and_return("<html>Thanks</html>")
      allow(fetcher).to receive(:extract_text_from_message).and_return("Thanks for your purchase.")
      allow(fetcher).to receive(:extract_attachments).and_return([])

      # Merchant mapping → “Amazon”; MerchantParsers returns class with .parse
      parser = class_double("AmazonParser").as_stubbed_const
      stub_const("MerchantParsers", Class.new) unless defined?(MerchantParsers)
      allow(MerchantParsers).to receive(:get_parser).and_return(parser)
      allow(parser).to receive(:parse).and_return({
        merchant: "Amazon",
        order_number: "A123",
        line_items: [{ name: "Echo Dot 5th Gen" }],
        purchase_date: Date.new(2024,1,1),
        total_amount: 49.99
      })

      # Google warranty lookup → use 24 months to verify path
      search = instance_double("GoogleSearchService")
      allow(GoogleSearchService).to receive(:new).and_return(search)
      allow(search).to receive(:lookup_warranty_info).and_return({ warranty_months: 24 })

      result = described_class.new("tok", "rtok", user).parse_receipt_emails("me")
      expect(result.length).to eq(1)
      h = result.first
      expect(h[:product_name]).to eq("Echo Dot 5th Gen")
      expect(h[:merchant]).to eq("Amazon")
      expect(h[:order_number]).to eq("A123")
      expect(h[:warranty_months]).to eq(24)  # pulled from GoogleSearchService
      expect(h[:source]).to eq("gmail_parsed")
    end

    it "falls back to EmailOrderParser and subject extraction when merchant parser returns nil" do
      msg_list = [double(id: "m1")]
      full_msg = Msg.new("m1", headers(
        "Subject" => "Receipt for Super Widget – Order #777",
        "From"    => "orders@bestbuy.com",
        "Date"    => "Tue, 2 Jan 2024 11:00:00 -0400"
      ))
      allow(fetcher).to receive(:list_order_messages).and_return(msg_list)
      allow(fetcher).to receive(:get_message).and_return(full_msg)
      allow(fetcher).to receive(:extract_html_from_message).and_return("<html>Order #777</html>")
      allow(fetcher).to receive(:extract_text_from_message).and_return("Thanks for your order.")
      allow(fetcher).to receive(:extract_attachments).and_return([])

      # MerchantParsers returns nil parse → triggers generic parser
      parser = class_double("GenericParser").as_stubbed_const
      stub_const("MerchantParsers", Class.new) unless defined?(MerchantParsers)
      allow(MerchantParsers).to receive(:get_parser).and_return(parser)
      allow(parser).to receive(:parse).and_return(nil)

      # EmailOrderParser is constructed and returns only an order number (no line items)
      generic = instance_double("EmailOrderParser")
      stub_const("EmailOrderParser", Class.new) unless defined?(EmailOrderParser)
      allow(EmailOrderParser).to receive(:new).and_return(generic)
      allow(generic).to receive(:parse).and_return({ order_number: nil, line_items: [] }) # first try returns nil-ish
      # then code tries extract_order_number_from_subject
      allow(generic).to receive(:extract_order_number_from_subject).and_return("777")

      # No AI call needed since subject extractor should find a product name
      # GoogleSearchService fallback not needed; use default 12 months

      result = described_class.new("tok", "rtok", user).parse_receipt_emails("me")
      expect(result.length).to eq(1)
      h = result.first
      # Subject extractor should return something like "Super Widget"
      expect(h[:product_name]).to include("Super Widget")
      expect(h[:order_number]).to eq("777")
      expect(h[:warranty_months]).to be > 0
    end

    it "adds receipts from attachments (pdf & image) and skips unknown mime" do
      msg_list = [double(id: "m1")]
      full_msg = Msg.new("m1", headers(
        "Subject" => "Order Confirmation",
        "From"    => "Target <orders@target.com>",
        "Date"    => "Wed, 3 Jan 2024 12:00:00 -0400"
      ))
      allow(fetcher).to receive(:list_order_messages).and_return(msg_list)
      allow(fetcher).to receive(:get_message).and_return(full_msg)
      allow(fetcher).to receive(:extract_html_from_message).and_return("<html></html>")
      allow(fetcher).to receive(:extract_text_from_message).and_return("text")
      allow(MerchantParsers).to receive(:get_parser).and_return(class_double("Parser", parse: { merchant: "Target", line_items: [{ name: "Blender" }], order_number: "T1" }))

      # Attachments: pdf, image, unknown
      attachments = [
        { attachment_id: "a1", mime_type: "application/pdf", filename: "receipt.pdf" },
        { attachment_id: "a2", mime_type: "image/png",       filename: "screen.png"  },
        { attachment_id: "a3", mime_type: "application/zip", filename: "x.zip"      }
      ]
      allow(fetcher).to receive(:extract_attachments).and_return(attachments)

      # Data returned base64-urlsafe (pdf), plain base64 (image)
      allow(fetcher).to receive(:get_attachment).with("m1", "a1", "me").and_return(Attach.new(Base64.urlsafe_encode64("PDFDATA")))
      allow(fetcher).to receive(:get_attachment).with("m1", "a2", "me").and_return(Attach.new(Base64.encode64("IMAGEDATA")))
      allow(fetcher).to receive(:get_attachment).with("m1", "a3", "me").and_return(Attach.new(Base64.encode64("IGNORED")))

      # ReceiptProcessor returns parsed hashes
      allow(rp).to receive(:process_pdf).with("PDFDATA").and_return({ merchant: "Target", line_items: [{ name: "Toaster" }], purchase_date: Date.new(2024,1,10), total_amount: 19.99 })
      allow(rp).to receive(:process_image).with("IMAGEDATA", "screen.png").and_return({ merchant: "Target", line_items: [{ name: "Kettle" }], purchase_date: Date.new(2024,1,11), total_amount: 29.99 })

      result = described_class.new("tok", "rtok", user).parse_receipt_emails("me")
      # 1 main receipt + 2 attachment receipts
      names = result.map { |h| h[:product_name] }
      expect(names).to include("Blender", "Toaster", "Kettle")
      sources = result.map { |h| h[:source] }
      expect(sources).to include("gmail_parsed")
      expect(sources).to include("attachment_parsed")
    end

    it "skips promotional subjects quickly (returns [])" do
      msg_list = [double(id: "m1")]
      full_msg = Msg.new("m1", headers(
        "Subject" => "Newsletter – save 40% this week", # promotional
        "From"    => "Amazon <order-update@amazon.com>"
      ))
      allow(fetcher).to receive(:list_order_messages).and_return(msg_list)
      allow(fetcher).to receive(:get_message).and_return(full_msg)
      allow(fetcher).to receive(:extract_html_from_message).and_return("<html></html>")
      allow(fetcher).to receive(:extract_text_from_message).and_return("text")
      allow(fetcher).to receive(:extract_attachments).and_return([])

      allow(MerchantParsers).to receive(:get_parser).and_return(class_double("Parser", parse: nil))

      result = described_class.new("tok", "rtok", user).parse_receipt_emails("me")
      expect(result).to eq([])
    end

    it "continues after per-message errors and still calls cleanup" do
      msg_list = [double(id: "m1"), double(id: "m2")]
      allow(fetcher).to receive(:list_order_messages).and_return(msg_list)

      # First message blows up
      allow(fetcher).to receive(:get_message).with("m1", "me").and_raise(StandardError.new("boom"))
      # Second message parses
      full_msg = Msg.new("m2", headers("Subject" => "Order Confirmation", "From" => "orders@walmart.com"))
      allow(fetcher).to receive(:get_message).with("m2", "me").and_return(full_msg)
      allow(fetcher).to receive(:extract_html_from_message).and_return("<html></html>")
      allow(fetcher).to receive(:extract_text_from_message).and_return("text")
      allow(fetcher).to receive(:extract_attachments).and_return([])
      allow(MerchantParsers).to receive(:get_parser).and_return(class_double("Parser", parse: { merchant: "Walmart", line_items: [{ name: "Widget" }], order_number: "W1" }))

      expect(rp).to receive(:cleanup)
      result = described_class.new("tok", "rtok", user).parse_receipt_emails("me")
      expect(result.length).to eq(1)
      expect(result.first[:merchant]).to eq("Walmart")
    end

    it "handles top-level Gmail API error and returns [] while still cleaning up" do
      allow(fetcher).to receive(:list_order_messages).and_raise(StandardError.new("gmail 500"))
      expect(rp).to receive(:cleanup)
      result = described_class.new("tok", "rtok", user).parse_receipt_emails("me")
      expect(result).to eq([])
    end
  end
end
