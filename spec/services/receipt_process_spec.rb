# spec/services/receipt_processor_spec.rb
require "rails_helper"

RSpec.describe ReceiptProcessor do
  let(:user) { User.create!(email: "t@example.com", password: "password123", password_confirmation: "password123") }

  # Doubles for collaborators
  let(:vision) { instance_double("GoogleVisionService") }
  let(:ai)     { instance_double("AiService") }

  before do
    # Replace collaborators constructed in initialize
    allow(GoogleVisionService).to receive(:new).and_return(vision)
    allow(AiService).to receive(:new).and_return(ai)

    # These are read via instance_variable_get in the code; stub them
    allow(vision).to receive(:instance_variable_get).with(:@api_key).and_return(nil)
    allow(vision).to receive(:instance_variable_get).with(:@user).and_return(nil)

    # Default stubs (tests override as needed)
    allow(vision).to receive(:extract_text_from_pdf).and_return(nil)
    allow(vision).to receive(:extract_text_from_image).and_return(nil)
    allow(ai).to receive(:extract_receipt_info_from_image).and_return(nil)
    allow(ai).to receive(:extract_receipt_info).and_return(nil)
  end

  describe "#process_pdf" do
    it "returns nil when no data present" do
      rp = described_class.new(user)
      expect(rp.process_pdf(nil)).to be_nil
    end

    it "returns parsed data when Vision extracts text" do
      rp = described_class.new(user)
      sample_text = <<~TXT
        Thank you for shopping at Best Buy
        Date: 2024-03-01
        Part Number: ABC
        Super Gadget 3000
        $199.99
        Total: $199.99
        Order Number: ZYX-123456
      TXT
      allow(vision).to receive(:extract_text_from_pdf).and_return(sample_text)

      # Avoid AI path: ensure regex finds items
      result = rp.process_pdf("PDFDATA")
      expect(result).to be_a(Hash)
      expect(result[:merchant]).to match(/Best Buy/i)
      expect(result[:purchase_date]).to eq(Date.new(2024,3,1))
      expect(result[:line_items]&.first&.dig(:name)).to eq("Super Gadget 3000")
      expect(result[:total_amount]).to be_within(0.01).of(199.99)
      expect(result[:order_number]).to include("ZYX")
    end

    it "rescues errors and returns nil" do
      rp = described_class.new(user)
      allow(vision).to receive(:extract_text_from_pdf).and_raise(StandardError.new("boom"))
      expect(rp.process_pdf("PDFDATA")).to be_nil
    end
  end

  describe "#process_image" do
    it "returns nil when no data present" do
      rp = described_class.new(user)
      expect(rp.process_image(nil)).to be_nil
    end

    it "when Vision text is blank but AI says is_receipt=true, returns formatted AI result" do
      rp = described_class.new(user)
      allow(vision).to receive(:extract_text_from_image).and_return("")
      allow(ai).to receive(:extract_receipt_info_from_image).and_return({
        "is_receipt" => true,
        "product_name" => "Echo Dot 5th Gen",
        "merchant" => "Amazon",
        "purchase_date" => "2024-02-15",
        "warranty_length_months" => 12,
        "warranty_type" => "manufacturer",
        "return_policy_days" => 30,
        "return_deadline" => "2024-03-30"
      })

      out = rp.process_image("IMGDATA", "photo.png")
      expect(out[:product_name]).to eq("Echo Dot 5th Gen")
      expect(out[:merchant]).to eq("Amazon")
      expect(out[:purchase_date]).to eq(Date.new(2024,2,15))
      expect(out[:return_deadline]).to eq(Date.new(2024,3,30))
      expect(out[:line_items].first[:name]).to eq("Echo Dot 5th Gen")
    end

    it "with Vision text + regex items returns regex result when AI not confident" do
      rp = described_class.new(user)

      text = <<~TXT
        Walmart
        Date: 2024/01/10
        Part Number: PN-1
        Turbo Blender Pro
        $89.99
        Total: $89.99
      TXT
      allow(vision).to receive(:extract_text_from_image).and_return(text)
      allow(ai).to receive(:extract_receipt_info_from_image).and_return({ "is_receipt" => false })

      res = rp.process_image("IMG", "x.png")
      expect(res[:merchant]).to match(/Walmart/i)
      expect(res[:purchase_date]).to eq(Date.new(2024,1,10))
      expect(res[:line_items].first[:name]).to eq("Turbo Blender Pro")
      expect(res[:total_amount]).to be_within(0.01).of(89.99)
    end

    it "prefers AI product name when regex finds an invalid product name" do
      rp = described_class.new(user)

      # Force regex parse to return a bad product name so code chooses AI
      allow(vision).to receive(:extract_text_from_image).and_return("Part Number:\nreceipt\nTotal: $10.00\n")
      allow_any_instance_of(ReceiptProcessor).to receive(:parse_receipt_text).and_return({
        merchant: "Target",
        purchase_date: Date.new(2024,1,1),
        line_items: [{ name: "receipt" }], # invalid by is_valid_product_name
        total_amount: 10.0,
        order_number: "ABC123"
      })

      allow(ai).to receive(:extract_receipt_info_from_image).and_return({
        "is_receipt" => true,
        "product_name" => "Ceramic Mug",
        "merchant" => "Target",
        "purchase_date" => "2024-01-01",
        "warranty_length_months" => 12,
        "warranty_type" => "manufacturer",
        "return_policy_days" => 30,
        "return_deadline" => nil
      })

      res = rp.process_image("IMG", "p.png")
      expect(res[:product_name]).to eq("Ceramic Mug") # AI chosen
      expect(res[:merchant]).to eq("Target")
    end

    it "on Vision PERMISSION_DENIED rescues and uses AI fallback" do
      rp = described_class.new(user)
      allow(vision).to receive(:extract_text_from_image).and_raise(StandardError.new("PERMISSION_DENIED"))
      allow(ai).to receive(:extract_receipt_info_from_image).and_return({
        "is_receipt" => true,
        "product_name" => "Phone Case",
        "merchant" => "Apple",
        "purchase_date" => "2024-04-01",
        "warranty_length_months" => 12,
        "warranty_type" => "manufacturer",
        "return_policy_days" => 14,
        "return_deadline" => "2024-04-15"
      })

      out = rp.process_image("IMGDATA", "x.png")
      expect(out[:product_name]).to eq("Phone Case")
      expect(out[:merchant]).to eq("Apple")
    end

    it "returns nil when neither Vision nor AI can help" do
      rp = described_class.new(user)
      allow(vision).to receive(:extract_text_from_image).and_return("")
      allow(ai).to receive(:extract_receipt_info_from_image).and_return(nil)
      expect(rp.process_image("IMG", "p.png")).to be_nil
    end
  end

  describe "#cleanup" do
    it "closes and unlinks temp files" do
      rp = described_class.new(user)
      f = rp.send(:create_temp_file, "DATA", ".jpg")
      path = f.path
      expect(File.exist?(path)).to be true
      rp.cleanup
      expect(File.exist?(path)).to be false
      # also ensures it clears the internal array without raising
      expect { rp.cleanup }.not_to raise_error
    end
  end

  describe "private helpers" do
    let(:rp) { described_class.new(user) }

    it "parse_date_string handles multiple formats" do
      expect(rp.send(:parse_date_string, "1/2/24")).to eq(Date.new(2024,1,2))
      expect(rp.send(:parse_date_string, "01-02-2024")).to eq(Date.new(2024,1,2))
      expect(rp.send(:parse_date_string, "2024/01/02")).to eq(Date.new(2024,1,2))
      expect(rp.send(:parse_date_string, "Feb 5, 2023")).to eq(Date.new(2023,2,5))
      expect(rp.send(:parse_date_string, "bad")).to be_nil
    end

    it "is_valid_product_name filters out obvious non-products" do
      expect(rp.send(:is_valid_product_name, "customer service")).to be false
      expect(rp.send(:is_valid_product_name, "receipt")).to be false
      expect(rp.send(:is_valid_product_name, "12345")).to be false
      expect(rp.send(:is_valid_product_name, "$19.99")).to be false
      expect(rp.send(:is_valid_product_name, "Super Gadget 3000")).to be true
    end

    it "parse_price handles US and EU formats" do
      expect(rp.send(:parse_price, "1,234.56")).to eq(1234.56)  # US
      expect(rp.send(:parse_price, "1.234,56")).to eq(1234.56)  # EU
      expect(rp.send(:parse_price, "123,45")).to eq(123.45)     # EU decimal
      expect(rp.send(:parse_price, "9.999.999,99")).to eq(9_999_999.99)
      expect(rp.send(:parse_price, nil)).to be_nil
    end
  end
end
