require 'cucumber/rails'
require 'capybara/rails'
require 'capybara/cucumber'
require 'capybara/session'
require 'omniauth'
require 'omniauth/test'
require 'database_cleaner/active_record'

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

Before do
  clear_oauth_mocks
  DatabaseCleaner.start
  Capybara.reset_sessions!
end

After do
  clear_oauth_mocks
  DatabaseCleaner.clean
  Capybara.reset_sessions!
end