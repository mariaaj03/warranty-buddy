# spec/requests/dashboard_request_spec.rb
require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) do
    User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  before { sign_in user }

  describe "GET /dashboard" do
    it "renders successfully" do
      get dashboard_path
      expect(response).to have_http_status(:ok)
    end

    it "redirects to sign in when not authenticated" do
      sign_out user
      get dashboard_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "sets gmail status" do
      allow(user).to receive(:gmail_connected?).and_return(true)
      get dashboard_path
      expect(response).to have_http_status(:ok)
    end

    it "filters by search term" do
      user.products.create!(product_name: "iPhone", merchant: "Apple", purchase_date: Date.today)
      # Mock the search scope on the Product class
      allow(Product).to receive_message_chain(:where, :search).and_return(user.products)
      
      get dashboard_path, params: { search: "iPhone" }
      expect(response).to have_http_status(:ok)
    end

    it "filters by status - active" do
      user.products.create!(product_name: "iPhone", merchant: "Apple", purchase_date: Date.today, warranty_months: 12)
      # Mock the active scope - it should return products that are still under warranty
      allow_any_instance_of(Product).to receive(:status).and_return("Active")
      
      get dashboard_path, params: { status: "active" }
      expect(response).to have_http_status(:ok)
    end

    it "filters by status - expired" do
      user.products.create!(product_name: "Old Phone", merchant: "Apple", purchase_date: 2.years.ago, warranty_months: 12)
      # Mock the expired scope
      allow_any_instance_of(Product).to receive(:status).and_return("Expired")
      
      get dashboard_path, params: { status: "expired" }
      expect(response).to have_http_status(:ok)
    end

    it "filters by status - expiring_soon" do
      user.products.create!(product_name: "Phone", merchant: "Apple", purchase_date: 11.months.ago, warranty_months: 12)
      # Mock the expiring_soon scope
      allow_any_instance_of(Product).to receive(:status).and_return("Expiring Soon")
      
      get dashboard_path, params: { status: "expiring_soon" }
      expect(response).to have_http_status(:ok)
    end

    it "filters by merchant" do
      user.products.create!(product_name: "iPhone", merchant: "Apple", purchase_date: Date.today)
      
      get dashboard_path, params: { merchant: "Apple" }
      expect(response).to have_http_status(:ok)
    end

    it "sorts by expiry_date (default)" do
      get dashboard_path
      expect(response).to have_http_status(:ok)
    end

    it "sorts by product_name" do
      get dashboard_path, params: { sort: "product_name" }
      expect(response).to have_http_status(:ok)
    end

    it "sorts by purchase_date" do
      get dashboard_path, params: { sort: "purchase_date" }
      expect(response).to have_http_status(:ok)
    end

    it "sorts by merchant" do
      get dashboard_path, params: { sort: "merchant" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /upload" do
    let(:receipt_processor) { instance_double("ReceiptProcessor") }

    before do
      allow(ReceiptProcessor).to receive(:new).and_return(receipt_processor)
      allow(receipt_processor).to receive(:cleanup)
    end

    # Helper method to create proper uploaded file mock
    def create_uploaded_file(filename, content = "fake content")
      # Create a proper ActionDispatch::Http::UploadedFile-like object
      file_path = Rails.root.join('tmp', filename)
      File.write(file_path, content)
      
      Rack::Test::UploadedFile.new(file_path, 'application/pdf', true)
    end

    it "handles PDF upload successfully" do
      allow(receipt_processor).to receive(:process_pdf).and_return({
        merchant: "Amazon",
        purchase_date: Date.today,
        warranty_length_months: 12,
        line_items: [{ name: "Echo Dot" }]
      })

      uploaded_file = create_uploaded_file("receipt.pdf")

      post "/upload", params: { receipt_file: uploaded_file }
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:notice]).to match(/Receipt processed and warranty added!/)
    end

    it "handles image upload successfully" do
      allow(receipt_processor).to receive(:process_image).and_return({
        merchant: "Target",
        purchase_date: Date.today,
        warranty_length_months: 6,
        line_items: [{ name: "Toaster" }]
      })

      uploaded_file = create_uploaded_file("receipt.png")

      post "/upload", params: { receipt_file: uploaded_file }
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:notice]).to match(/Receipt processed and warranty added!/)
    end

    it "handles manual product entry without receipt" do
      post "/upload", params: {
        product: "Manual Product",
        merchant: "Test Store",
        purchase_date: Date.today.to_s,
        warranty_length: "24"
      }
      
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:notice]).to match(/Warranty added successfully!/)
    end

    it "rejects unsupported file types" do
      uploaded_file = create_uploaded_file("document.txt")

      post "/upload", params: { receipt_file: uploaded_file }
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:alert]).to match(/Unsupported file type/)
    end

    it "handles receipt processing errors" do
      allow(receipt_processor).to receive(:process_pdf).and_raise(StandardError, "Processing failed")
      allow(Rails.logger).to receive(:error)

      uploaded_file = create_uploaded_file("receipt.pdf")

      post "/upload", params: { receipt_file: uploaded_file }
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:alert]).to match(/Error processing receipt/)
    end

    it "requires product name for manual entry" do
      post "/upload", params: { merchant: "Test Store" }
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:alert]).to match(/Product name is required/)
    end

    it "handles bad date parsing gracefully" do
      post "/upload", params: {
        product: "Test Product",
        purchase_date: "invalid-date"
      }
      
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:notice]).to match(/Warranty added successfully!/)
    end

    it "uses AI service for warranty lookup when no receipt data" do
      ai_service = instance_double("AiService")
      allow(AiService).to receive(:new).and_return(ai_service)
      allow(ai_service).to receive(:lookup_warranty_info).and_return({
        "standard_warranty_months" => 24,
        "return_policy_days" => 30,
        "warranty_type" => "manufacturer"
      })

      post "/upload", params: {
        product: "iPhone",
        merchant: "Apple"
      }
      
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:notice]).to match(/Warranty added successfully!/)
    end

    it "handles AI service errors gracefully" do
      ai_service = instance_double("AiService")
      allow(AiService).to receive(:new).and_return(ai_service)
      allow(ai_service).to receive(:lookup_warranty_info).and_raise(StandardError, "AI failed")
      allow(Rails.logger).to receive(:error)

      post "/upload", params: {
        product: "iPhone",
        merchant: "Apple"
      }
      
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:notice]).to match(/Warranty added successfully!/)
    end

    it "defaults to 12 months for receipt uploads only" do
      allow(receipt_processor).to receive(:process_pdf).and_return({
        merchant: "Amazon",
        purchase_date: Date.today,
        line_items: [{ name: "Echo Dot" }]
        # No warranty_length_months provided
      })

      uploaded_file = create_uploaded_file("receipt.pdf")

      expect {
        post "/upload", params: { receipt_file: uploaded_file }
      }.to change(user.products, :count).by(1)

      product = user.products.last
      expect(product.warranty_months).to eq(12)
    end

    it "does not default warranty for manual uploads" do
      expect {
        post "/upload", params: {
          product: "Manual Product",
          merchant: "Test Store"
        }
      }.to change(user.products, :count).by(1)

      product = user.products.last
      expect(product.warranty_months).to be_nil
    end
  end

  describe "GET /dashboard/api_warranties" do
    it "returns warranties as JSON" do
      product = user.products.create!(
        product_name: "Test Product",
        merchant: "Test Store",
        purchase_date: Date.today,
        warranty_months: 12
      )
      
      get "/dashboard/api_warranties"
      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      expect(json_response).to be_an(Array)
      expect(json_response.first["product"]).to eq("Test Product")
      expect(json_response.first["merchant"]).to eq("Test Store")
      expect(json_response.first["id"]).to eq(product.id)
    end

    it "returns empty array when no warranties" do
      get "/dashboard/api_warranties"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq([])
    end
  end

  describe "GET /dashboard/api_health" do
    it "returns health status with gmail connected" do
      allow(user).to receive(:gmail_connected?).and_return(true)
      
      get "/dashboard/api_health"
      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      expect(json_response["ok"]).to eq(true)
      expect(json_response["gmail_connected"]).to eq(true)
    end

    it "returns health status with gmail not connected" do
      allow(user).to receive(:gmail_connected?).and_return(false)
      
      get "/dashboard/api_health"
      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      expect(json_response["ok"]).to eq(true)
      expect(json_response["gmail_connected"]).to eq(false)
    end
  end

  describe "GET /dashboard/reset" do
    it "resets gmail tokens" do
      user.update(gmail_token: "token", gmail_refresh_token: "refresh")
      
      get "/dashboard/reset"
      expect(response).to have_http_status(:ok)
      
      user.reload
      expect(user.gmail_token).to be_nil
      expect(user.gmail_refresh_token).to be_nil
    end
  end

  describe "POST /disconnect_gmail" do
    it "disconnects gmail and redirects" do
      user.update(gmail_token: "token", gmail_refresh_token: "refresh")
      
      post "/disconnect_gmail"
      expect(response).to redirect_to(dashboard_path)
      
      user.reload
      expect(user.gmail_token).to be_nil
      expect(user.gmail_refresh_token).to be_nil
    end
  end

  describe "POST /parse_gmail_receipts" do
    it "requires gmail connection" do
      allow(user).to receive(:gmail_connected?).and_return(false)
      
      post "/parse_gmail_receipts"
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:alert]).to match(/connect your Gmail account/)
    end

    it "parses gmail receipts successfully" do
      allow(user).to receive(:gmail_connected?).and_return(true)
      
      gmail_service = instance_double("GmailService")
      allow(GmailService).to receive(:new).and_return(gmail_service)
      allow(gmail_service).to receive(:parse_receipt_emails).and_return([
        {
          product_name: "Test Product",
          merchant: "Test Store",
          purchase_date: Date.today,
          warranty_months: 12,
          source: "gmail_parsed",
          raw_email_id: "email123"
        }
      ])
      
      expect {
        post "/parse_gmail_receipts"
      }.to change(user.products, :count).by(1)
      
      expect(response).to redirect_to(dashboard_path)
    end

    it "skips products with blank names" do
      allow(user).to receive(:gmail_connected?).and_return(true)
      
      gmail_service = instance_double("GmailService")
      allow(GmailService).to receive(:new).and_return(gmail_service)
      allow(gmail_service).to receive(:parse_receipt_emails).and_return([
        {
          product_name: "",
          merchant: "Test Store",
          purchase_date: Date.today
        }
      ])
      
      expect {
        post "/parse_gmail_receipts"
      }.not_to change(user.products, :count)
    end

    it "skips duplicate emails" do
      allow(user).to receive(:gmail_connected?).and_return(true)
      
      # Create existing product
      user.products.create!(
        product_name: "Existing",
        merchant: "Store",
        purchase_date: Date.today,
        raw_email_id: "email123"
      )
      
      gmail_service = instance_double("GmailService")
      allow(GmailService).to receive(:new).and_return(gmail_service)
      allow(gmail_service).to receive(:parse_receipt_emails).and_return([
        {
          product_name: "Test Product",
          merchant: "Test Store",
          purchase_date: Date.today,
          warranty_months: 12,
          raw_email_id: "email123"
        }
      ])
      
      expect {
        post "/parse_gmail_receipts"
      }.not_to change(user.products, :count)
    end

    it "handles gmail parsing errors" do
      allow(user).to receive(:gmail_connected?).and_return(true)
      allow(Rails.logger).to receive(:error)
      
      gmail_service = instance_double("GmailService")
      allow(GmailService).to receive(:new).and_return(gmail_service)
      allow(gmail_service).to receive(:parse_receipt_emails).and_raise(StandardError, "Gmail error")
      
      post "/parse_gmail_receipts"
      expect(response).to redirect_to(dashboard_path)
    end

    it "handles permission denied errors" do
      allow(user).to receive(:gmail_connected?).and_return(true)
      allow(Rails.logger).to receive(:error)
      
      gmail_service = instance_double("GmailService")
      allow(GmailService).to receive(:new).and_return(gmail_service)
      allow(gmail_service).to receive(:parse_receipt_emails).and_raise(StandardError, "PERMISSION_DENIED")
      
      post "/parse_gmail_receipts"
      expect(response).to redirect_to(dashboard_path)
    end
  end

  describe "POST /check_warranty_eligibility" do
    let(:product) { user.products.create!(product_name: "Test Product", merchant: "Store", purchase_date: Date.today) }

    it "requires gmail connection (JSON)" do
      allow(user).to receive(:gmail_connected?).and_return(false)
      
      post "/check_warranty_eligibility", params: { 
        product_id: product.id, 
        issue_description: "broken" 
      }, as: :json
      
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to eq("Gmail not connected")
    end

    it "requires issue description (JSON)" do
      allow(user).to receive(:gmail_connected?).and_return(true)
      
      post "/check_warranty_eligibility", params: { 
        product_id: product.id, 
        issue_description: "" 
      }, as: :json
      
      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)["error"]).to eq("Please describe the issue")
    end

    it "checks warranty eligibility successfully" do
      allow(user).to receive(:gmail_connected?).and_return(true)
      allow_any_instance_of(Product).to receive(:check_warranty_eligibility).and_return({
        "eligible" => true,
        "reasoning" => "Within warranty period"
      })
      
      post "/check_warranty_eligibility", params: { 
        product_id: product.id, 
        issue_description: "broken screen" 
      }, as: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response["eligible"]).to eq(true)
    end

    it "handles product not found (JSON)" do
      allow(user).to receive(:gmail_connected?).and_return(true)
      
      post "/check_warranty_eligibility", params: { 
        product_id: 99999, 
        issue_description: "broken" 
      }, as: :json
      
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["error"]).to eq("Product not found")
    end
  end

  describe "GET /lookup_warranty_info" do
    it "looks up warranty info successfully" do
      ai_service = instance_double("AiService")
      allow(AiService).to receive(:new).and_return(ai_service)
      allow(ai_service).to receive(:lookup_warranty_info).and_return({
        "standard_warranty_months" => 12,
        "return_policy_days" => 30
      })
      
      get "/lookup_warranty_info", params: { 
        product_name: "iPhone", 
        merchant: "Apple" 
      }, as: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response["standard_warranty_months"]).to eq(12)
    end
  end

  describe "DELETE /warranties/:id" do
    it "deletes existing product" do
      # Create the product first, then capture its ID
      product = user.products.create!(
        product_name: "Test Product", 
        merchant: "Store", 
        purchase_date: Date.today
      )
      product_id = product.id
      
      # Verify the product exists
      expect(user.products.find_by(id: product_id)).to be_present
      
      # Delete it and verify the change
      expect {
        delete "/warranties/#{product_id}"
      }.to change { user.products.count }.by(-1)
      
      expect(response).to have_http_status(:ok)
      
      # Verify it's actually gone
      expect(user.products.find_by(id: product_id)).to be_nil
    end

    it "returns 404 for non-existent product" do
      delete "/warranties/99999"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /warranties/:id" do
    let(:product) { user.products.create!(product_name: "Test Product", merchant: "Store", purchase_date: Date.today) }

    it "updates existing product successfully" do
      patch "/warranties/#{product.id}", params: {
        product_name: "Updated Product",
        merchant: "New Store", 
        purchase_date: Date.tomorrow.to_s,
        warranty_months: 24
      }
      
      expect(response).to have_http_status(:ok)
      
      product.reload
      expect(product.product_name).to eq("Updated Product")
      expect(product.merchant).to eq("New Store")
      expect(product.warranty_months).to eq(24)
    end

    it "handles bad date format" do
      allow(Rails.logger).to receive(:error)
      
      patch "/warranties/#{product.id}", params: {
        product_name: "Updated Product",
        merchant: "Store",
        purchase_date: "invalid-date",
        warranty_months: 12
      }
      
      expect(response).to have_http_status(:bad_request)
    end

    it "returns 404 for non-existent product" do
      patch "/warranties/99999", params: { 
        product_name: "Test" 
      }
      
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "private methods" do
    it "sets gmail status in before_action" do
      allow(user).to receive(:gmail_connected?).and_return(true)
      get dashboard_path
      expect(response).to have_http_status(:ok)
    end
  end
end
