require "rails_helper"

RSpec.describe "Users::OmniauthCallbacks", type: :request do
  before do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  def auth_hash(token: "tok123", refresh_token: "ref123", email: "u@example.com", uid: "12345")
    OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: OmniAuth::AuthHash.new(
        email: email,
        name: "Test User"
      ),
      credentials: OmniAuth::AuthHash.new(
        token: token,
        refresh_token: refresh_token
      )
    )
  end


  describe "Failure handling" do
    it "handles OAuth failures through exception handling" do
      # Mock an exception that would occur during OAuth processing
      allow(User).to receive(:from_omniauth).and_raise(StandardError.new("OAuth error"))

      OmniAuth.config.mock_auth[:google_oauth2] = auth_hash

      get "/users/auth/google_oauth2/callback"

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to match(/Authentication failed/i)
    end

    it "redirects to root with alert on failure" do
      controller = Users::OmniauthCallbacksController.new
      allow(controller).to receive(:redirect_to)
      allow(controller).to receive(:root_path).and_return("/")
      
      controller.failure
      
      expect(controller).to have_received(:redirect_to).with("/", alert: "Authentication failed. Please try again.")
    end
  end
end