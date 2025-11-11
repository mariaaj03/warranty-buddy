require "google/apis/vision_v1"
require "googleauth"
require "base64"
require "net/http"
require "json"
require "uri"
require "cgi"
require "tempfile"

class GoogleVisionService
  def initialize(api_key = nil)
    @api_key = api_key || ENV["GOOGLE_VISION_API_KEY"] || Rails.application.credentials.dig(:google, :vision_api_key)
    @service = Google::Apis::VisionV1::VisionService.new
    setup_authorization
  end

  def extract_text_from_image(image_data)
    return nil unless @service.authorization || @api_key

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

        request = Net::HTTP::Post.new(uri.request_uri)
        request["Content-Type"] = "application/json"
        request.body = request_body.to_json

        response = http.request(request)

        if response.code == "200"
          result = JSON.parse(response.body)
          annotations = result.dig("responses", 0, "textAnnotations")
          return annotations&.first&.dig("description") || ""
        else
          Rails.logger.error "Vision API error: #{response.code} - #{response.body}"
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
      Rails.logger.error "Vision API call failed: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      nil
    end
  end

  def extract_text_from_pdf(pdf_data)
    Rails.logger.warn "PDF processing via Vision API requires Document AI or async batch operations. Falling back to basic extraction."
    
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
      Rails.logger.error "PDF::Reader gem not available for PDF processing"
      nil
    rescue => e
      Rails.logger.error "PDF processing failed: #{e.message}"
      nil
    end
  end

  private

  def setup_authorization
    return if @api_key

    credentials_path = Rails.application.credentials.dig(:google, :service_account_path)
    if credentials_path && File.exist?(credentials_path)
      @service.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: File.open(credentials_path),
        scope: "https://www.googleapis.com/auth/cloud-vision"
      )
    end
  end
end

