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

    describe '#extract_date_from_receipt' do
      it "extracts warranty end date and calculates purchase date" do
        text = <<~TXT
          Product: Laptop
          Coverage End Date: March 15, 2026
          Warranty Period: 24 months
        TXT
        result = rp.send(:extract_date_from_receipt, text)
        expect(result).to eq(Date.new(2024, 3, 15))
      end

      it "handles warranty until format" do
        text = "Warranty valid until: January 1, 2027\n24 months warranty"
        result = rp.send(:extract_date_from_receipt, text)
        expect(result).to eq(Date.new(2025, 1, 1))
      end

      it "defaults to 12 months when warranty period not found" do
        text = "Coverage End Date: December 31, 2025"
        result = rp.send(:extract_date_from_receipt, text)
        expect(result).to eq(Date.new(2024, 12, 31))
      end

      it "handles year warranty format" do
        text = "Expires on: June 30, 2026\n2 year warranty"
        result = rp.send(:extract_date_from_receipt, text)
        expect(result).to eq(Date.new(2024, 6, 30))
      end

      it "extracts purchase date when no warranty date found" do
        text = "Date of purchase: 05/15/2024\nProduct: Item"
        result = rp.send(:extract_date_from_receipt, text)
        expect(result).to eq(Date.new(2024, 5, 15))
      end

      it "strips time from date strings" do
        text = "Date of purchase: March 15, 2024 14:30:00"
        result = rp.send(:extract_date_from_receipt, text)
        expect(result).to eq(Date.new(2024, 3, 15))
      end

      it "returns nil for invalid dates" do
        expect(rp.send(:extract_date_from_receipt, "No date here")).to be_nil
        expect(rp.send(:extract_date_from_receipt, "")).to be_nil
      end
    end

    describe '#extract_merchant_from_receipt' do

      it "handles case insensitive matching" do
        expect(rp.send(:extract_merchant_from_receipt, "target store")).to eq("Target")
      end

      it "returns nil when no merchant found" do
        expect(rp.send(:extract_merchant_from_receipt, "Some random store")).to be_nil
      end
    end

    describe '#extract_items_from_receipt' do
      it "extracts items with Part Number and price format" do
        text = <<~TXT
          Store Receipt
          Product Name Here
          Part Number: ABC123
          Some other text
          $49.99
        TXT
        items = rp.send(:extract_items_from_receipt, text)
        expect(items.length).to eq(1)
        expect(items.first[:name]).to eq("Product Name Here")
        expect(items.first[:price]).to eq(49.99)
      end

      it "looks back up to 8 lines for product name" do
        text = <<~TXT
          Amazing Product Name
          Line 1
          Line 2
          Line 3
          Line 4
          Line 5
          Line 6
          $99.99
        TXT
        items = rp.send(:extract_items_from_receipt, text)
        expect(items.first[:name]).to eq("Amazing Product Name")
      end

      it "filters out invalid product names" do
        text = <<~TXT
          receipt
          $10.00
          customer service
          $20.00
          Valid Product Name
          $30.00
        TXT
        items = rp.send(:extract_items_from_receipt, text)
        expect(items.length).to eq(1)
        expect(items.first[:name]).to eq("Valid Product Name")
      end

      it "limits to first 5 items" do
        text = (1..10).map { |i| "Product #{i}\n$#{i}.99" }.join("\n")
        items = rp.send(:extract_items_from_receipt, text)
        expect(items.length).to be <= 5
      end


      it "filters out email addresses" do
        text = "test@example.com\n$10.00\nProduct Name\n$20.00"
        items = rp.send(:extract_items_from_receipt, text)
        expect(items.first[:name]).to eq("Product Name")
      end
    end

    describe '#extract_total_from_receipt' do
      it "extracts total with various formats" do
        expect(rp.send(:extract_total_from_receipt, "Total: $99.99")).to eq(99.99)
        expect(rp.send(:extract_total_from_receipt, "Grand Total: 199.99")).to eq(199.99)
        expect(rp.send(:extract_total_from_receipt, "Amount Due: $49.99")).to eq(49.99)
        expect(rp.send(:extract_total_from_receipt, "Subtotal: $29.99")).to eq(29.99)
      end

      it "returns nil when no total found" do
        expect(rp.send(:extract_total_from_receipt, "No total here")).to be_nil
      end
    end

    describe '#extract_order_number_from_receipt' do
      it "extracts order numbers with various formats" do
        expect(rp.send(:extract_order_number_from_receipt, "Order Number: ABC-123456")).to eq("ABC-123456")
        expect(rp.send(:extract_order_number_from_receipt, "Order #: XYZ789")).to eq("XYZ789")
        expect(rp.send(:extract_order_number_from_receipt, "Receipt Number: 123-ABC-456")).to eq("123-ABC-456")
        expect(rp.send(:extract_order_number_from_receipt, "Transaction ID: TXN123456789")).to eq("TXN123456789")
      end

      it "returns nil when no order number found" do
        expect(rp.send(:extract_order_number_from_receipt, "No order here")).to be_nil
      end
    end

    describe '#parse_price' do
      it "handles only period as thousands separator" do
        expect(rp.send(:parse_price, "1.234")).to eq(1234.0)
        expect(rp.send(:parse_price, "1.234.567")).to eq(1234567.0)
      end

      it "handles only period as decimal" do
        expect(rp.send(:parse_price, "12.99")).to eq(12.99)
      end

      it "handles only comma as thousands separator" do
        expect(rp.send(:parse_price, "1,234")).to eq(1234.0)
      end

      it "handles blank input" do
        expect(rp.send(:parse_price, "")).to be_nil
        expect(rp.send(:parse_price, "   ")).to be_nil
      end

      it "handles currency symbols" do
        expect(rp.send(:parse_price, "$99.99")).to eq(99.99)
        expect(rp.send(:parse_price, "€49,99")).to eq(49.99)
      end

      it "rescues errors gracefully" do
        allow_any_instance_of(String).to receive(:to_f).and_raise(StandardError)
        expect(rp.send(:parse_price, "99.99")).to be_nil
      end
    end

    describe '#is_valid_product_name' do
      it "filters all invalid terms" do
        invalid = %w[
          warranty months support returns exchange refund policy
          terms conditions invoice confirmation total tax shipping
          discount www.example.com http://test.com
        ]
        invalid.each do |term|
          expect(rp.send(:is_valid_product_name, term)).to be false
        end
      end

      it "rejects names shorter than 3 characters" do
        expect(rp.send(:is_valid_product_name, "AB")).to be false
      end

    end

    describe '#determine_image_extension' do
      it "returns extension from filename" do
        expect(rp.send(:determine_image_extension, "photo.jpg")).to eq(".jpg")
        expect(rp.send(:determine_image_extension, "image.png")).to eq(".png")
        expect(rp.send(:determine_image_extension, "pic.JPEG")).to eq(".jpeg")
      end

      it "returns .jpg for unknown extensions" do
        expect(rp.send(:determine_image_extension, "file.txt")).to eq(".jpg")
      end

      it "returns nil for blank filename" do
        expect(rp.send(:determine_image_extension, nil)).to be_nil
        expect(rp.send(:determine_image_extension, "")).to be_nil
      end
    end

    describe '#parse_receipt_text_first' do
      it "returns nil for blank text" do
        expect(rp.send(:parse_receipt_text_first, "")).to be_nil
        expect(rp.send(:parse_receipt_text_first, nil)).to be_nil
      end

      it "uses regex result when line items found" do
        text = "Target\nDate: 2024-01-01\nPart Number: ABC\nProduct Name\n$10.00\nTotal: $10.00"
        allow(ai).to receive(:extract_receipt_info).and_return({ "is_receipt" => false })
        
        result = rp.send(:parse_receipt_text_first, text)
        expect(result[:product_name]).to eq("Product Name")
        expect(result[:merchant]).to eq("Target")
      end

      it "uses AI when regex has no items" do
        text = "Some text without products\nTotal: $10.00"
        allow(ai).to receive(:extract_receipt_info).and_return({
          "is_receipt" => true,
          "product_name" => "AI Product",
          "merchant" => "AI Store",
          "purchase_date" => "2024-01-01"
        })
        
        result = rp.send(:parse_receipt_text_first, text)
        expect(result[:product_name]).to eq("AI Product")
      end

      it "rescues AI errors and returns regex result" do
        text = "Target\nDate: 2024-01-01\nTotal: $10.00"
        allow(ai).to receive(:extract_receipt_info).and_raise(StandardError)
        
        result = rp.send(:parse_receipt_text_first, text)
        expect(result[:merchant]).to eq("Target")
      end
    end

    describe '#format_ai_result' do
      it "formats AI result with all fields" do
        ai_data = {
          "product_name" => "Test Product",
          "merchant" => "Test Store",
          "purchase_date" => "2024-01-15",
          "warranty_length_months" => 24,
          "warranty_type" => "extended",
          "return_policy_days" => 60,
          "return_deadline" => "2024-03-15"
        }
        
        result = rp.send(:format_ai_result, ai_data)
        expect(result[:product_name]).to eq("Test Product")
        expect(result[:merchant]).to eq("Test Store")
        expect(result[:warranty_length_months]).to eq(24)
        expect(result[:warranty_type]).to eq("extended")
        expect(result[:return_policy_days]).to eq(60)
        expect(result[:line_items].first[:name]).to eq("Test Product")
      end
    end
  end

  describe "integration scenarios" do
    it "handles AI failure gracefully in process_image" do
      rp = described_class.new(user)
      text = "Best Buy\nDate: 2024-01-01\nProduct ABC\n$99.99"
      
      allow(vision).to receive(:extract_text_from_image).and_return(text)
      allow(ai).to receive(:extract_receipt_info_from_image).and_raise(StandardError)
      
      result = rp.process_image("IMG", "test.jpg")
      expect(result).not_to be_nil
    end

    it "prefers longer regex product name over shorter AI name" do
      rp = described_class.new(user)
      
      text = "Amazon\nPart Number: ABC\nSuper Ultra Mega Product 3000 Pro\n$199.99"
      allow(vision).to receive(:extract_text_from_image).and_return(text)
      allow(ai).to receive(:extract_receipt_info_from_image).and_return({
        "is_receipt" => true,
        "product_name" => "Product",
        "merchant" => "Amazon"
      })
      
      result = rp.process_image("IMG", "test.jpg")
      expect(result[:product_name]).to include("Super Ultra Mega")
    end
  end
end
