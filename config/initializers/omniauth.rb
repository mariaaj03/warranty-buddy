OmniAuth.config.allowed_request_methods = %i[post get]

client_id     = ENV["GOOGLE_CLIENT_ID"]     || Rails.application.credentials.dig(:google, :client_id)
client_secret = ENV["GOOGLE_CLIENT_SECRET"] || Rails.application.credentials.dig(:google, :client_secret)
redirect_uri  = ENV["GOOGLE_OAUTH_REDIRECT_URI"] || Rails.application.credentials.dig(:google, :redirect_uri)

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
           client_id,
           client_secret,
           {
             scope: "openid email profile https://www.googleapis.com/auth/gmail.readonly",
             access_type: "offline",
             prompt: "consent",
             redirect_uri: redirect_uri
           }
end
