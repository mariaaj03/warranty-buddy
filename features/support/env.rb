require 'cucumber/rails'
require 'capybara/rails'
require 'capybara/cucumber'
require 'capybara/session'
require 'omniauth'
require 'omniauth/test'
require 'database_cleaner/active_record'
require 'rspec/mocks'
require 'warden/test/helpers'

Capybara.default_driver = :rack_test
Capybara.javascript_driver = :selenium_chrome_headless

Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1280,720')

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

OmniAuth.config.test_mode = true
OmniAuth.config.logger = Rails.logger
Rails.application.config.force_ssl = false

require_relative 'oauth_test_helper'
require_relative 'test_helpers'

DatabaseCleaner.strategy = :transaction
DatabaseCleaner.clean_with(:truncation)

# Include RSpec::Mocks in the Cucumber World
World(RSpec::Mocks::ExampleMethods)

# Include Warden test helpers for login_as
World(Warden::Test::Helpers)

# Set up RSpec mocks for each scenario
Before do
  RSpec::Mocks.setup
end

Before do
  clear_oauth_mocks
  DatabaseCleaner.start
  Capybara.reset_sessions!
end

After do
  RSpec::Mocks.verify
  RSpec::Mocks.teardown
  # Reset Warden after each scenario if login_as was used
  begin
    logout(:user) if respond_to?(:logout)
  rescue
    # Ignore if logout is not available
  end
  clear_oauth_mocks
  DatabaseCleaner.clean
  Capybara.reset_sessions!
end
