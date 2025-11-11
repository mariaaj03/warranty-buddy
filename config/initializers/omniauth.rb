require "omniauth"

OmniAuth.config.allowed_request_methods = %i[post get]

# Devise will handle the OmniAuth configuration
# This is set in config/initializers/devise.rb
