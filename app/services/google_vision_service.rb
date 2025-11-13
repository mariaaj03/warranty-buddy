require "google/apis/vision_v1"
require "googleauth"
require "base64"
require "net/http"
require "json"
require "uri"
require "cgi"
require "tempfile"

class GoogleVisionService
  def initialize(api_key = nil, user = nil)
    @api_key = api_key || ENV["GOOGLE_VISION_API_KEY"] || Rails.application.credentials.dig(:google, :vision_api_key)
    @user = user
    @service = Google::Apis::VisionV1::VisionService.new
    setup_authorization
  end

  def extract_text_from_image(image_data)
    unless @service.authorization || @api_key
      return nil
    end

    begin
      if @api_key
        request_body = {
          requests: [{
            image: {
              content: Base64.strict_encode64(image_data)
            },
            features: [{
              type: "DOCUMENT_TEXT_DETECTION",
              maxResults: 1
            }]
          }]
        }

        uri = URI("https://vision.googleapis.com/v1/images:annotate?key=#{CGI.escape(@api_key)}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        
        # In development, allow self-signed certificates and skip CRL checks
        if Rails.env.development?
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end

        request = Net::HTTP::Post.new(uri.request_uri)
        request["Content-Type"] = "application/json"
        request.body = request_body.to_json

        response = http.request(request)

        if response.code == "200"
          result = JSON.parse(response.body)
          annotations = result.dig("responses", 0, "textAnnotations")
          return annotations&.first&.dig("description") || ""
        else
          return nil
        end
      else
        image_obj = Google::Apis::VisionV1::Image.new(content: Base64.strict_encode64(image_data))
        feature = Google::Apis::VisionV1::Feature.new(type: "DOCUMENT_TEXT_DETECTION", max_results: 1)
        request = Google::Apis::VisionV1::AnnotateImageRequest.new(image: image_obj, features: [feature])

        response = @service.annotate_image(request)
        return response.text_annotations&.first&.description || ""
      end
    rescue => e
      nil
    end
  end

  def extract_text_from_pdf(pdf_data)
    begin
      require "pdf-reader"
      temp_file = Tempfile.new(["receipt", ".pdf"])
      temp_file.binmode
      temp_file.write(pdf_data)
      temp_file.rewind

      reader = PDF::Reader.new(temp_file.path)
      text = ""
      reader.pages.each do |page|
        text += page.text + "\n"
      end
      temp_file.close
      temp_file.unlink

      text
    rescue LoadError
      nil
    rescue => e
      nil
    end
  end

  private

  def setup_authorization
    return if @api_key

    if @user && @user.gmail_token.present? && @user.gmail_refresh_token.present?
      setup_oauth_authorization
      return
    end

  end

  def setup_oauth_authorization
    require "googleauth"
    
    client_id = Rails.application.credentials.dig(:google, :client_id) || ENV["GOOGLE_CLIENT_ID"]
    client_secret = Rails.application.credentials.dig(:google, :client_secret) || ENV["GOOGLE_CLIENT_SECRET"]
    
    return unless client_id.present? && client_secret.present?
    
    credentials = Google::Auth::UserRefreshCredentials.new(
      client_id: client_id,
      client_secret: client_secret,
      refresh_token: @user.gmail_refresh_token,
      access_token: @user.gmail_token,
      scope: "https://www.googleapis.com/auth/cloud-vision"
    )
    
    if credentials.expired? || credentials.expires_at.nil? || (credentials.expires_at && credentials.expires_at < Time.now)
      begin
        credentials.refresh!
        @user.update(
          gmail_token: credentials.access_token,
          gmail_refresh_token: credentials.refresh_token || @user.gmail_refresh_token
        )
      rescue => e
        return
      end
    end
    
    @service.authorization = credentials
  end
end

