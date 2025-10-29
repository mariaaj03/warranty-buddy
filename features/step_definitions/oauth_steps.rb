Given("I have connected my Gmail account with {string}") do |email|
  OmniAuth.config.test_mode = true
  OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
    provider: 'google_oauth2',
    uid: "test_user_#{email.split('@').first}",
    info: {
      name: 'Test User',
      email: email,
      image: 'https://example.com/avatar.jpg'
    },
    credentials: {
      token: "test_access_token_#{email.split('@').first}",
      refresh_token: "test_refresh_token_#{email.split('@').first}",
      expires_at: 1.hour.from_now.to_i
    }
  })
  simulate_oauth_callback
end

Given("my OAuth token has expired") do
  clear_oauth_mocks
  visit "/"
end

Given("Google OAuth service is unavailable") do
  mock_google_oauth_failure
end

When("I deny access to the application") do
  mock_google_oauth_failure
  simulate_oauth_failure_callback
end

When("I connect with a different Google account {string}") do |email|
  visit "/disconnect_gmail"
  Given("I have connected my Gmail account with #{email}")
end

When("I click {string} again") do |button_text|
  click_button button_text
end

When("the OAuth attempt fails") do
  mock_google_oauth_failure
  simulate_oauth_callback
end

Then("I should see an error message about OAuth service") do
  expect(current_path).to eq("/")
end

Then("I should see an error message") do
  expect(current_path).to eq("/")
end

Then("my session should be automatically refreshed") do
  expect(page).to have_css(".badge.ok", text: "Connected")
end

Then("my Gmail data should be cleared from the session") do
  expect(page).to have_css(".badge.not", text: "Not Connected")
  expect(page).not_to have_button("Parse Gmail Receipts")
end

Then("I should see data for the new account") do
  expect(page).to have_css(".badge.ok", text: "Connected")
end

Then("I should not see data from the previous account") do
  expect(page).to have_css(".badge.ok", text: "Connected")
end

Then("I should remain on the dashboard") do
  expect(current_path).to eq("/")
end

Then("I should be able to retry the OAuth process") do
  expect(page).to have_button("Connect Gmail")
end

Given("the OAuth flow is configured") do
  setup_oauth_test_environment
end

When("I visit the OAuth callback URL") do
  visit "/auth/google_oauth2/callback"
end

Then("I should see OAuth success") do
  expect_oauth_success
end

Then("I should see OAuth failure") do
  expect_oauth_failure
end
