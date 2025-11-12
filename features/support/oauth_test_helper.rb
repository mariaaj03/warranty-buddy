# features/support/oauth_test_helper.rb
module OauthTestHelper
  include Rails.application.routes.url_helpers

  def setup_oauth_test_environment
    OmniAuth.config.test_mode = true
    OmniAuth.config.allowed_request_methods = %i[get post]
    # Devise’s default prefix; harmless if already set:
    OmniAuth.config.path_prefix = "/users/auth"
  end

  def mock_google_oauth_success(email: "user@example.com", uid: "123")
    setup_oauth_test_environment
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: {
        name: "Test User",
        email: email,
        image: "https://example.com/avatar.jpg"
      },
      credentials: {
        token: "test_access_token_#{uid}",
        refresh_token: "test_refresh_token_#{uid}",
        expires_at: 1.hour.from_now.to_i
      }
    )
  end

  def mock_google_oauth_failure(message: "invalid_credentials")
    setup_oauth_test_environment
    OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials
    OmniAuth.config.on_failure = proc { |env| OmniAuth::FailureEndpoint.new(env).redirect_to_failure }
    @__oauth_failure_message = message
  end

  # In test mode, visiting the authorize path triggers the callback automatically.
  def simulate_oauth_callback
    visit user_google_oauth2_omniauth_authorize_path
  end

  def simulate_oauth_failure_callback(message: "access_denied")
    # Set up the failure in OmniAuth
    OmniAuth.config.mock_auth[:google_oauth2] = message.to_sym
    
    # Visit the callback URL which will trigger the failure
    visit "/users/auth/google_oauth2/callback"
    
    # Or directly visit the failure route
    visit "/users/auth/failure?message=#{message}&strategy=google_oauth2"
  end

  def clear_oauth_mocks
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  # Optional convenience assertions
  def expect_oauth_success
    expect(page).to have_css(".badge.ok", text: "Connected")
  end

  def expect_oauth_failure
    expect(current_path).to eq(root_path)
    expect(page).to have_css(".badge.not", text: "Not Connected")
  end
end

World(OauthTestHelper)

# Default host for url_helpers in features
def default_url_options
  { host: "www.example.com" }
end
