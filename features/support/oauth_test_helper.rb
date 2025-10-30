module OAuthTestHelper
  def setup_oauth_test_environment
    # Configure test OAuth credentials
    Rails.application.config.omniauth = {
      google_oauth2: {
        client_id: ENV['GOOGLE_OAUTH_CLIENT_ID'] || 'test_client_id',
        client_secret: ENV['GOOGLE_OAUTH_CLIENT_SECRET'] || 'test_client_secret',
        scope: 'email,profile,gmail.readonly'
      }
    }
  end

  def mock_google_oauth_success
    # Mock successful OAuth response
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
      provider: 'google_oauth2',
      uid: 'test_user_123',
      info: {
        name: 'Test User',
        email: 'test@example.com',
        image: 'https://example.com/avatar.jpg'
      },
      credentials: {
        token: 'test_access_token_123',
        refresh_token: 'test_refresh_token_123',
        expires_at: 1.hour.from_now.to_i
      }
    })
  end

  def mock_google_oauth_failure
    # Mock failed OAuth response
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials
  end

  def clear_oauth_mocks
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  def simulate_oauth_callback
    # Simulate the OAuth callback with mock data
    visit "/auth/google_oauth2/callback"
  end

  def simulate_oauth_failure_callback
    # Simulate OAuth failure callback
    visit "/auth/failure"
  end

  def expect_oauth_redirect
    # Check that we're being redirected to Google OAuth
    expect(current_url).to include('accounts.google.com')
  end

  def expect_oauth_success
    # Check that OAuth was successful
    expect(page).to have_content('Connected')
    expect(page).to have_css('.badge.ok')
  end

  def expect_oauth_failure
    # Check that OAuth failed
    expect(page).to have_content('Not Connected')
    expect(page).to have_css('.badge.not')
  end
end

World(OAuthTestHelper)
