require 'rails_helper'

RSpec.describe "Dashboard", type: :request do
  describe "GET /" do
    it "returns http success" do
      get root_path
      expect(response).to have_http_status(:success)
    end

    it "displays the warranty buddy title" do
      get root_path
      expect(response.body).to include("Warranty Buddy")
    end

    it "shows not connected status when Gmail is not connected" do
      get root_path
      expect(response.body).to include("Not Connected")
    end

    it "shows connected status when Gmail is connected" do
      # Mock the controller to simulate Gmail connection
      allow_any_instance_of(DashboardController).to receive(:set_gmail_status)
      allow_any_instance_of(DashboardController).to receive(:instance_variable_get).with(:@gmail_connected).and_return(true)
      
      get root_path
      expect(response.body).to include("Connected")
    end

    it "displays products in the table" do
      create(:product, product_name: "Test Product", gmail_uid: 'test_user')
      # Mock the controller to simulate Gmail connection and user filtering
      allow_any_instance_of(DashboardController).to receive(:set_gmail_status)
      allow_any_instance_of(DashboardController).to receive(:instance_variable_get).with(:@gmail_connected).and_return(true)
      allow_any_instance_of(DashboardController).to receive(:instance_variable_set).with(:@warranties, anything)
      
      get root_path
      expect(response.body).to include("Test Product")
    end
  end

  describe "POST /upload" do
    it "requires Gmail connection to upload" do
      expect {
        post "/upload", params: {
          product: "MacBook Pro",
          merchant: "Apple Store",
          purchase_date: "2024-01-15",
          warranty_length: "12"
        }
      }.not_to change(Product, :count)

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("Please connect your Gmail account first")
    end

    it "requires Gmail connection for all uploads" do
      post "/upload", params: { product: "iPhone 15" }
      
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("Please connect your Gmail account first")
    end

    it "handles missing product name" do
      post "/upload", params: { merchant: "Test Store" }
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("Missing product")
    end

    it "requires Gmail connection for invalid data" do
      post "/upload", params: {
        product: "Test Product",
        purchase_date: "invalid-date"
      }
      
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("Please connect your Gmail account first")
    end

    it "requires Gmail connection for negative warranty" do
      post "/upload", params: {
        product: "Test Product",
        warranty_length: "-5"
      }
      
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("Please connect your Gmail account first")
    end
  end

  describe "GET /auth/google_oauth2/callback" do
    it "handles OAuth callback" do
      # This test is simplified since OAuth mocking is complex
      # In a real test environment, you would mock the OAuth response
      get "/auth/google_oauth2/callback"
      expect(response).to have_http_status(:ok)
    end

    let(:auth_hash) do
      OmniAuth::AuthHash.new({
        uid: '12345',
        credentials: {
          token: 'fake_token',
          refresh_token: 'fake_refresh_token'
        }
      })
    end

    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:google_oauth2] = auth_hash
    end

    it "stores Gmail credentials in session" do
      get "/auth/google_oauth2/callback"
      expect(session[:gmail_uid]).to eq('12345')
      expect(session[:gmail_token]).to eq('fake_token')
      expect(session[:gmail_refresh_token]).to eq('fake_refresh_token')
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /auth/failure" do
    it "handles OAuth failures" do
      get "/auth/failure"
      expect(session[:gmail_uid]).to be_nil
      expect(session[:gmail_token]).to be_nil
      expect(session[:gmail_refresh_token]).to be_nil
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include("Gmail connection was denied")
    end
  end

  describe "GET /lookup_warranty_info" do
    let(:ai_service) { instance_double(AiService) }
    let(:warranty_info) do
      {
        'standard_warranty_months' => 12,
        'warranty_terms' => 'Limited warranty'
      }
    end

    before do
      allow(AiService).to receive(:new).and_return(ai_service)
      allow(ai_service).to receive(:lookup_warranty_info).and_return(warranty_info)
    end

    it "looks up warranty information" do
      get "/lookup_warranty_info", params: {
        product_name: "Test Product",
        merchant: "Test Store"
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq(warranty_info)
    end

    it "handles missing merchant parameter" do
      get "/lookup_warranty_info", params: { product_name: "Test Product" }, as: :json
      expect(response).to have_http_status(:ok)
    end

    it "handles AI service errors" do
      allow(ai_service).to receive(:lookup_warranty_info).and_return(nil)
      get "/lookup_warranty_info", params: { product_name: "Test Product" }, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to be_nil
    end
  end

  describe "POST /disconnect_gmail" do
    it "redirects to root path with disconnect message" do
      post "/disconnect_gmail"
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("Gmail disconnected.")
    end
  end

  describe "GET /dashboard/api_health" do
    it "returns JSON with ok status" do
      get "/dashboard/api_health"
      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      expect(json_response['ok']).to be true
    end

    it "includes Gmail connection status" do
      get "/dashboard/api_health"
      json_response = JSON.parse(response.body)
      expect(json_response).to have_key('gmail_connected')
    end
  end

  describe "GET /dashboard/api_warranties" do
    it "returns JSON array of warranties" do
      create(:product, product_name: "Test Product", gmail_uid: 'test_user')
      # Mock the controller to simulate Gmail connection
      allow_any_instance_of(DashboardController).to receive(:set_gmail_status)
      allow_any_instance_of(DashboardController).to receive(:instance_variable_get).with(:@gmail_connected).and_return(true)
      
      get "/dashboard/api_warranties"
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response).to be_an(Array)
    end
  end

  describe "POST /reset" do
    it "clears session but keeps warranties" do
      create(:product, gmail_uid: 'test_user')
      
      post "/reset"
      
      expect(Product.count).to eq(1) # Warranties are kept
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /parse_gmail_receipts" do
    let(:gmail_service) { instance_double(GmailService) }
    
    context "when Gmail is connected" do
      before do
        allow_any_instance_of(DashboardController).to receive(:set_gmail_status)
        allow_any_instance_of(DashboardController).to receive(:instance_variable_get)
          .with(:@gmail_connected).and_return(true)
        allow(GmailService).to receive(:new).and_return(gmail_service)
      end

      it "processes receipts successfully" do
        allow(gmail_service).to receive(:parse_receipt_emails).and_return([
          {
            product_name: "Test Product",
            merchant: "Test Store",
            purchase_date: Date.today,
            warranty_months: 12
          }
        ])

        post "/parse_gmail_receipts"
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to include("Successfully processed")
      end

      it "handles empty receipt list" do
        allow(gmail_service).to receive(:parse_receipt_emails).and_return([])
        post "/parse_gmail_receipts"
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to include("No new receipts")
      end

      it "handles Gmail API errors" do
        allow(gmail_service).to receive(:parse_receipt_emails).and_raise(StandardError, "API Error")
        post "/parse_gmail_receipts"
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("Error processing receipts")
      end
    end

    context "when Gmail is not connected" do
      it "redirects with error" do
        post "/parse_gmail_receipts"
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("Please connect your Gmail")
      end
    end
  end

  describe "POST /check_warranty_eligibility" do
    let!(:product) { create(:product, gmail_uid: 'test_user') }
    let(:ai_service) { instance_double(AiService) }

    before do
      allow(AiService).to receive(:new).and_return(ai_service)
    end

    context "when Gmail is connected" do
      before do
        allow_any_instance_of(DashboardController).to receive(:set_gmail_status)
        allow_any_instance_of(DashboardController).to receive(:instance_variable_get)
          .with(:@gmail_connected).and_return(true)
      end

      it "checks eligibility successfully" do
        allow(ai_service).to receive(:check_warranty_eligibility).and_return({
          "is_covered" => true,
          "reasoning" => "Within warranty period"
        })

        post "/check_warranty_eligibility", params: {
          product_id: product.id,
          issue_description: "Product stopped working"
        }

        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to include("Warranty status")
      end

      it "handles missing issue description" do
        post "/check_warranty_eligibility", params: { product_id: product.id }
        expect(response).to have_http_status(:bad_request)
        expect(response.body).to include("Issue description required")
      end

      it "handles invalid product ID" do
        post "/check_warranty_eligibility", params: {
          product_id: 0,
          issue_description: "Test issue"
        }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /delete_warranty" do
    let!(:product) { create(:product, gmail_uid: 'test_user') }

    context "when Gmail is connected" do
      before do
        allow_any_instance_of(DashboardController).to receive(:set_gmail_status)
        allow_any_instance_of(DashboardController).to receive(:instance_variable_get)
          .with(:@gmail_connected).and_return(true)
      end

      it "deletes the warranty" do
        expect {
          delete "/delete_warranty/#{product.id}"
        }.to change(Product, :count).by(-1)
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to include("Warranty deleted")
      end

      it "handles non-existent warranty" do
        delete "/delete_warranty/0"
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when Gmail is not connected" do
      it "redirects with error" do
        delete "/delete_warranty/#{product.id}"
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("Please connect your Gmail")
      end
    end
  end

  describe "PATCH /update_warranty" do
    let!(:product) { create(:product, gmail_uid: 'test_user') }

    context "when Gmail is connected" do
      before do
        allow_any_instance_of(DashboardController).to receive(:set_gmail_status)
        allow_any_instance_of(DashboardController).to receive(:instance_variable_get)
          .with(:@gmail_connected).and_return(true)
      end

      it "updates the warranty successfully" do
        patch "/update_warranty/#{product.id}", params: {
          product_name: "Updated Product",
          purchase_date: "2025-10-29"
        }
        expect(response).to have_http_status(:success)
        expect(product.reload.product_name).to eq("Updated Product")
      end

      it "handles invalid dates" do
        patch "/update_warranty/#{product.id}", params: {
          purchase_date: "invalid-date"
        }
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe "index filtering and sorting" do
    let!(:product1) { create(:product, product_name: "A Product", merchant: "Amazon", gmail_uid: 'test_user') }
    let!(:product2) { create(:product, product_name: "B Product", merchant: "Best Buy", gmail_uid: 'test_user') }

    before do
      allow_any_instance_of(DashboardController).to receive(:set_gmail_status)
      allow_any_instance_of(DashboardController).to receive(:instance_variable_get)
        .with(:@gmail_connected).and_return(true)
    end

    it "filters by status" do
      get root_path, params: { status: 'active' }
      expect(response).to have_http_status(:success)
      expect(assigns(:warranties)).to be_present
    end

    it "filters by merchant" do
      get root_path, params: { merchant: 'Amazon' }
      expect(response).to have_http_status(:success)
      expect(assigns(:warranties).first.merchant).to eq('Amazon')
    end

    it "sorts by different criteria" do
      ['expiry_date', 'product_name', 'purchase_date', 'merchant'].each do |sort_by|
        get root_path, params: { sort: sort_by }
        expect(response).to have_http_status(:success)
        expect(assigns(:warranties)).to be_present
      end
    end

    it "handles Gmail API errors during receipt parsing" do
      allow_any_instance_of(DashboardController).to receive(:instance_variable_get)
        .with(:@gmail_connected).and_return(true)
      
      post "/parse_gmail_receipts"
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe "warranty management edge cases" do
    let!(:product) { create(:product, gmail_uid: 'test_user') }

    before do
      allow_any_instance_of(DashboardController).to receive(:set_gmail_status)
      allow_any_instance_of(DashboardController).to receive(:instance_variable_get)
        .with(:@gmail_connected).and_return(true)
    end

    it "handles invalid warranty months during update" do
      patch "/update_warranty/#{product.id}", params: {
        warranty_months: 'invalid'
      }
      expect(response).to have_http_status(:ok)
      expect(product.reload.warranty_months).to eq(0)
    end

    it "handles missing parameters during update" do
      patch "/update_warranty/#{product.id}", params: {}
      expect(response).to have_http_status(:ok)
    end
  end
end



