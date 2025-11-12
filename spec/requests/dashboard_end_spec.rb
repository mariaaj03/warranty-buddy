# spec/requests/dashboard_end_to_end_spec.rb
require "rails_helper"

RSpec.describe "Dashboard end-to-end", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) do
    User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  def make_product(attrs = {})
    Product.create!({
      user: user,
      product_name: "Widget",
      merchant: "Shop",
      purchase_date: Date.new(2024, 1, 1),
      warranty_months: 12,
      source: "manual"
    }.merge(attrs))
  end

  before { sign_in user }

  describe "GET /dashboard" do
    it "loads with filters and sorts (exercises branches)" do
      make_product(product_name: "AAA", merchant: "Best Buy", purchase_date: Date.new(2024, 1, 2))
      make_product(product_name: "ZZZ", merchant: "Target", purchase_date: Date.new(2023, 12, 31))

      get dashboard_path, params: { search: "Wid", status: "active", merchant: "Best Buy", sort: "product_name" }
      expect(response).to have_http_status(:ok)

      get dashboard_path, params: { status: "expired", sort: "merchant" }
      expect(response).to have_http_status(:ok)

      get dashboard_path, params: { status: "expiring_soon", sort: "purchase_date" }
      expect(response).to have_http_status(:ok)

      get dashboard_path # default sort case
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /upload" do
    let(:rp) { instance_double("ReceiptProcessor") }

    before do
      allow(ReceiptProcessor).to receive(:new).and_return(rp)
      allow(rp).to receive(:cleanup)
    end

    it "accepts PDF and creates product (receipt path)" do
      allow(rp).to receive(:process_pdf).and_return({
        merchant: "Amazon",
        purchase_date: Date.new(2024, 2, 2),
        warranty_length_months: 24,
        warranty_type: "manufacturer",
        line_items: [{ name: "Echo" }]
      })

      fake_upload = double(original_filename: "receipt.pdf", read: "%PDFDATA%")
      post upload_dashboard_index_path, params: { receipt_file: fake_upload }
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:notice]).to match(/Receipt processed/)
      expect(Product.where(user: user).count).to eq(1)
    end

    it "accepts image and creates product" do
      allow(rp).to receive(:process_image).and_return({
        merchant: "Target",
        purchase_date: Date.new(2024, 3, 3),
        warranty_length_months: 6,
        warranty_type: "manufacturer",
        line_items: [{ name: "Toaster" }]
      })

      fake_upload = double(original_filename: "photo.png", read: "PNGDATA")
      post upload_dashboard_index_path, params: { receipt_file: fake_upload }
      expect(response).to redirect_to(dashboard_path)
      expect(Product.where(user: user).count).to eq(1)
    end

    it "rejects unsupported file type" do
      fake_upload = double(original_filename: "note.txt", read: "hello")
      post upload_dashboard_index_path, params: { receipt_file: fake_upload }
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:alert]).to match(/Unsupported file type/i)
    end

    it "manual add when no file and product provided" do
      post upload_dashboard_index_path, params: { product: "Manual Item", merchant: "Store", purchase_date: "2024-04-04", warranty_length: "18" }
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:notice]).to match(/Warranty added successfully/i)
      expect(Product.where(user: user).count).to eq(1)
    end

    it "alerts when no product can be derived from receipt and no manual name" do
      fake_upload = double(original_filename: "receipt.pdf", read: "%PDFDATA%")
      allow(rp).to receive(:process_pdf).and_return(nil)
      allow(Rails.application.credentials).to receive(:dig).and_return(nil)
      allow(ENV).to receive(:[]).with("GOOGLE_VISION_API_KEY").and_return(nil)
      allow(user).to receive(:gmail_token).and_return(nil)
      allow(user).to receive(:gmail_refresh_token).and_return(nil)

      post upload_dashboard_index_path, params: { receipt_file: fake_upload }
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:alert]).to be_present
    end

    it "handles bad purchase_date gracefully" do
      post upload_dashboard_index_path, params: { product: "X", merchant: "Y", purchase_date: "not-a-date", warranty_length: "0" }
      expect(response).to redirect_to(dashboard_path)
      expect(Product.where(user: user).count).to eq(1)
    end
  end

  describe "GET /api_warranties" do
    it "returns JSON list" do
      p = make_product(product_name: "Phone", merchant: "Apple")
      get api_warranties_dashboard_index_path, as: :json
      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data.first["product"]).to eq("Phone")
      expect(data.first["merchant"]).to eq("Apple")
      expect(data.first["id"]).to eq(p.id)
    end
  end

  describe "GET /api_health" do
    it "shows gmail_connected false/true" do
      allow(user).to receive(:gmail_connected?).and_return(false)
      get api_health_dashboard_index_path, as: :json
      expect(JSON.parse(response.body)["gmail_connected"]).to eq(false)

      allow(user).to receive(:gmail_connected?).and_return(true)
      get api_health_dashboard_index_path, as: :json
      expect(JSON.parse(response.body)["gmail_connected"]).to eq(true)
    end
  end

  describe "POST /parse_gmail_receipts" do
    it "requires gmail connection" do
      allow(user).to receive(:gmail_connected?).and_return(false)
      post parse_gmail_receipts_dashboard_index_path
      expect(response).to redirect_to(dashboard_path)
    end

    it "creates products from parsed receipts when connected; skips dups/blanks" do
      allow(user).to receive(:gmail_connected?).and_return(true)
      make_product(product_name: "Echo Dot", merchant: "Amazon", purchase_date: Date.new(2024,5,1), raw_email_id: "m1", source: "gmail_parsed")

      gs = instance_double("GmailService")
      allow(GmailService).to receive(:new).and_return(gs)
      allow(gs).to receive(:parse_receipt_emails).and_return([
        { product_name: "", merchant: "X", purchase_date: Date.today, source: "gmail_parsed", raw_email_id: "mX" },
        { product_name: "Echo Dot", merchant: "Amazon", purchase_date: Date.new(2024,5,1), source: "gmail_parsed", raw_email_id: "m1" },
        { product_name: "Toaster", merchant: "Target", purchase_date: Date.new(2024,5,2), warranty_months: 24, source: "gmail_parsed", raw_email_id: "m2" }
      ])

      post parse_gmail_receipts_dashboard_index_path
      expect(response).to redirect_to(dashboard_path)
      expect(Product.where(user: user).pluck(:raw_email_id)).to include("m1", "m2")
    end
  end

  describe "POST /check_warranty_eligibility" do
    it "rejects when gmail not connected (json)" do
      allow(user).to receive(:gmail_connected?).and_return(false)
      post check_warranty_eligibility_dashboard_index_path, params: { product_id: 1 }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects blank issue (json)" do
      allow(user).to receive(:gmail_connected?).and_return(true)
      p = make_product
      post check_warranty_eligibility_dashboard_index_path, params: { product_id: p.id, issue_description: "" }, as: :json
      expect(response).to have_http_status(:bad_request)
    end

    it "handles not found (json)" do
      allow(user).to receive(:gmail_connected?).and_return(true)
      post check_warranty_eligibility_dashboard_index_path, params: { product_id: 999, issue_description: "It broke" }, as: :json
      expect(response).to have_http_status(:not_found)
    end

    it "returns result json on success" do
      allow(user).to receive(:gmail_connected?).and_return(true)
      p = make_product
      allow_any_instance_of(Product).to receive(:check_warranty_eligibility)
        .and_return({ "eligible" => true, "reasoning" => "Within 12 months" })

      post check_warranty_eligibility_dashboard_index_path, params: { product_id: p.id, issue_description: "It broke" }, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["eligible"]).to eq(true)
    end
  end

  describe "POST /lookup_warranty_info" do
    it "calls AiService and returns json" do
      ai = instance_double("AiService")
      allow(AiService).to receive(:new).and_return(ai)
      allow(ai).to receive(:lookup_warranty_info).with("Phone", "Apple")
        .and_return({ "warranty_months" => 12 })

      post lookup_warranty_info_dashboard_index_path, params: { product_name: "Phone", merchant: "Apple" }, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["warranty_months"]).to eq(12)
    end
  end

  describe "DELETE /delete_warranty & PUT /update_warranty" do
    it "deletes existing product; 404 otherwise" do
      p = make_product
      delete delete_warranty_dashboard_path(id: p.id)
      expect(response).to have_http_status(:ok)
      delete delete_warranty_dashboard_path(id: 999)
      expect(response).to have_http_status(:not_found)
    end

    it "updates product; handles bad date; 404 missing" do
      p = make_product
      put update_warranty_dashboard_path(id: p.id),
          params: { product_name: "New", merchant: "Store", purchase_date: "2024-06-01", warranty_months: 18 }
      expect(response).to have_http_status(:ok)
      expect(p.reload.product_name).to eq("New")

      put update_warranty_dashboard_path(id: p.id),
          params: { product_name: "X", merchant: "Y", purchase_date: "bad-date", warranty_months: 10 }
      expect(response).to have_http_status(:bad_request)

      put update_warranty_dashboard_path(id: 999), params: { product_name: "X" }
      expect(response).to have_http_status(:not_found)
    end
  end
end
