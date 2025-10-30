source "https://rubygems.org"

ruby "3.2.2" # add your Ruby version if missing

gem "rails", "~> 8.1.0"
gem "propshaft"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"
gem "tzinfo-data", platforms: %i[windows jruby]

gem "solid_cache"
gem "solid_queue"
gem "solid_cable"
gem "bootsnap", require: false
gem "kamal", require: false
gem "thruster", require: false
gem "image_processing", "~> 1.2"

# --- moved to top-level so prod has them ---
gem "omniauth"
gem "omniauth-google-oauth2"
gem "omniauth-rails_csrf_protection"
gem "google-api-client"
gem "icalendar"
gem "nokogiri"
gem "mail"
gem "pdf-reader"
gem "rtesseract"
gem "chronic"
gem "money"
# Include if AiService is used in prod; otherwise you can leave it dev/test:
gem "gemini-ai", "~> 4.3.0"
# ------------------------------------------

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false

  gem "rspec-rails", "~> 6.0"
  gem "cucumber-rails", require: false
  gem "factory_bot_rails"

  gem "dotenv-rails" # dev/test only
end

group :development do
  gem "web-console"
  gem "rerun"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "simplecov", require: false
  gem "database_cleaner-active_record"
end
