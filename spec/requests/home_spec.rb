require 'rails_helper'

RSpec.describe "Homes", type: :request do
  describe "GET /index" do
    context "when user is not signed in" do
      it "returns http success" do
        # Use the correct route - likely root_path or /
        get root_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when user is signed in" do
      include Devise::Test::IntegrationHelpers
      
      let(:user) do
        User.create!(
          email: "test@example.com",
          password: "password123",
          password_confirmation: "password123"
        )
      end

      it "redirects to dashboard" do
        sign_in user
        get root_path
        expect(response).to redirect_to(dashboard_path)
      end
    end
  end
end
