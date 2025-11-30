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

      # If no text extracted (scanned PDF), try OCR via image conversion
      if text.strip.blank?
        text = extract_text_from_scanned_pdf(temp_file.path)
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

  def extract_text_from_scanned_pdf(pdf_path)
    require "mini_magick"
    require "pdf-reader"
    
    text = ""
    
    # Get number of pages in PDF
    reader = PDF::Reader.new(pdf_path)
    page_count = reader.pages.count
    
    # Convert each PDF page to an image and run OCR
    page_count.times do |page_num|
      temp_image = Tempfile.new(["pdf_page_#{page_num}", ".png"])
      
      begin
        # Use ImageMagick convert command to extract specific page
        # Syntax: convert input.pdf[0] output.png (0-based page index)
        MiniMagick::Tool::Convert.new do |convert|
          convert.density(300)
          convert.quality(100)
          convert << "#{pdf_path}[#{page_num}]"
          convert << temp_image.path
        end
        
        # Read the converted image and run OCR
        if File.exist?(temp_image.path) && File.size(temp_image.path) > 0
          image_data = File.binread(temp_image.path)
          page_text = extract_text_from_image(image_data)
          text += page_text + "\n" if page_text.present?
        end
      rescue => e
        Rails.logger.warn "Failed to convert PDF page #{page_num} to image: #{e.message}"
        # Skip this page and continue with next
      ensure
        temp_image.close
        temp_image.unlink if File.exist?(temp_image.path)
      end
    end
    
    text.presence
  rescue LoadError
    nil
  rescue => e
    Rails.logger.warn "Failed to extract text from scanned PDF: #{e.message}"
    nil
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

