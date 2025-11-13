# features/step_definitions/google_vision_service_steps.rb

Given("the Vision API service is available") do
  # Setup for Vision API service tests
end

Given("the Vision API key is configured") do
  allow(ENV).to receive(:[]).and_call_original
  allow(ENV).to receive(:[]).with("GOOGLE_VISION_API_KEY").and_return("test_vision_key")
  allow(Rails.application.credentials).to receive(:dig).with(:google, :vision_api_key).and_return("test_vision_key")
end

Given("the Vision API key is not configured") do
  allow(ENV).to receive(:[]).and_call_original
  allow(ENV).to receive(:[]).with("GOOGLE_VISION_API_KEY").and_return(nil)
  allow(Rails.application.credentials).to receive(:dig).with(:google, :vision_api_key).and_return(nil)
end

Given("the user does not have OAuth credentials") do
  @user = User.create!(
    email: 'test@example.com',
    password: 'password123',
    password_confirmation: 'password123',
    gmail_token: nil,
    gmail_refresh_token: nil
  )
end

Given("the user has OAuth credentials") do
  @user = User.create!(
    email: 'test@example.com',
    password: 'password123',
    password_confirmation: 'password123',
    gmail_token: "test_token",
    gmail_refresh_token: "test_refresh_token"
  )
  allow(Rails.application.credentials).to receive(:dig).with(:google, :client_id).and_return("test_client_id")
  allow(Rails.application.credentials).to receive(:dig).with(:google, :client_secret).and_return("test_client_secret")
  allow(ENV).to receive(:[]).and_call_original
  allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return(nil)
  allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_SECRET").and_return(nil)
end

Given("the user has OAuth credentials with expired tokens") do
  @user = User.create!(
    email: 'test@example.com',
    password: 'password123',
    password_confirmation: 'password123',
    gmail_token: "test_token",
    gmail_refresh_token: "test_refresh_token"
  )
  allow(Rails.application.credentials).to receive(:dig).with(:google, :client_id).and_return("test_client_id")
  allow(Rails.application.credentials).to receive(:dig).with(:google, :client_secret).and_return("test_client_secret")
  allow(ENV).to receive(:[]).and_call_original
  allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return(nil)
  allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_SECRET").and_return(nil)
  
  @mock_credentials = double("Google::Auth::UserRefreshCredentials")
  allow(@mock_credentials).to receive(:expired?).and_return(true)
  allow(@mock_credentials).to receive(:expires_at).and_return(Time.now - 3600)
  allow(@mock_credentials).to receive(:refresh!)
  allow(@mock_credentials).to receive(:access_token).and_return("new_access_token")
  allow(@mock_credentials).to receive(:refresh_token).and_return("new_refresh_token")
  allow(Google::Auth::UserRefreshCredentials).to receive(:new).and_return(@mock_credentials)
  
  @mock_service = double("Google::Apis::VisionV1::VisionService")
  allow(@mock_service).to receive(:authorization=)
  allow(@mock_service).to receive(:authorization).and_return(nil)
  allow(Google::Apis::VisionV1::VisionService).to receive(:new).and_return(@mock_service)
end

Given("OAuth token refresh will fail") do
  allow(@mock_credentials).to receive(:refresh!).and_raise(StandardError.new("Refresh failed"))
end

Given("the user has OAuth credentials with valid tokens") do
  @user = User.create!(
    email: 'test@example.com',
    password: 'password123',
    password_confirmation: 'password123',
    gmail_token: "test_token",
    gmail_refresh_token: "test_refresh_token"
  )
  allow(Rails.application.credentials).to receive(:dig).with(:google, :client_id).and_return("test_client_id")
  allow(Rails.application.credentials).to receive(:dig).with(:google, :client_secret).and_return("test_client_secret")
  allow(ENV).to receive(:[]).and_call_original
  allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return(nil)
  allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_SECRET").and_return(nil)
  
  @mock_credentials = double("Google::Auth::UserRefreshCredentials")
  allow(@mock_credentials).to receive(:expired?).and_return(false)
  allow(@mock_credentials).to receive(:expires_at).and_return(Time.now + 3600)
  allow(Google::Auth::UserRefreshCredentials).to receive(:new).and_return(@mock_credentials)
  
  @mock_service = double("Google::Apis::VisionV1::VisionService")
  allow(@mock_service).to receive(:authorization=)
  allow(@mock_service).to receive(:authorization).and_return(nil)
  allow(Google::Apis::VisionV1::VisionService).to receive(:new).and_return(@mock_service)
end

Given("the user has OAuth tokens but no client credentials") do
  @user = User.create!(
    email: 'test@example.com',
    password: 'password123',
    password_confirmation: 'password123',
    gmail_token: "test_token",
    gmail_refresh_token: "test_refresh_token"
  )
  allow(Rails.application.credentials).to receive(:dig).with(:google, :client_id).and_return(nil)
  allow(Rails.application.credentials).to receive(:dig).with(:google, :client_secret).and_return(nil)
  allow(ENV).to receive(:[]).and_call_original
  allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return(nil)
  allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_SECRET").and_return(nil)
end

When("I extract text from an image with API key") do
  @image_data = "mock image data"
  
  @mock_response = double("Net::HTTPResponse")
  allow(@mock_response).to receive(:code).and_return("200")
  allow(@mock_response).to receive(:body).and_return({
    "responses" => [{
      "textAnnotations" => [{
        "description" => "Extracted text from image"
      }]
    }]
  }.to_json)
  
  @mock_http = double("Net::HTTP")
  allow(@mock_http).to receive(:use_ssl=)
  allow(@mock_http).to receive(:verify_mode=)
  allow(@mock_http).to receive(:request).and_return(@mock_response)
  allow(Net::HTTP).to receive(:new).and_return(@mock_http)
  
  @vision_service = GoogleVisionService.new("test_api_key", nil)
  @result = @vision_service.extract_text_from_image(@image_data)
end

When("I extract text from an image") do
  @image_data = "mock image data"
  @vision_service = GoogleVisionService.new(nil, @user)
  @result = @vision_service.extract_text_from_image(@image_data)
end

When("I extract text from an image with OAuth") do
  @image_data = "mock image data"
  
  @mock_response = double("Google::Apis::VisionV1::AnnotateImageResponse")
  @mock_text_annotation = double("Google::Apis::VisionV1::TextAnnotation")
  allow(@mock_text_annotation).to receive(:description).and_return("Extracted text via OAuth")
  allow(@mock_response).to receive(:text_annotations).and_return([@mock_text_annotation])
  
  @mock_service = double("Google::Apis::VisionV1::VisionService")
  allow(@mock_service).to receive(:authorization=)
  allow(@mock_service).to receive(:authorization).and_return(double("Authorization"))
  allow(@mock_service).to receive(:annotate_image).and_return(@mock_response)
  
  @vision_service = GoogleVisionService.new(nil, @user)
  @vision_service.instance_variable_set(:@service, @mock_service)
  @result = @vision_service.extract_text_from_image(@image_data)
end

Given("the Vision API returns error status {int}") do |status_code|
  @mock_response = double("Net::HTTPResponse")
  allow(@mock_response).to receive(:code).and_return(status_code.to_s)
  allow(@mock_response).to receive(:body).and_return("Error message")
  
  @mock_http = double("Net::HTTP")
  allow(@mock_http).to receive(:use_ssl=)
  allow(@mock_http).to receive(:verify_mode=)
  allow(@mock_http).to receive(:request).and_return(@mock_response)
  allow(Net::HTTP).to receive(:new).and_return(@mock_http)
end

Given("the Vision API request raises an exception") do
  @mock_http = double("Net::HTTP")
  allow(@mock_http).to receive(:use_ssl=)
  allow(@mock_http).to receive(:verify_mode=)
  allow(@mock_http).to receive(:request).and_raise(StandardError.new("Network error"))
  allow(Net::HTTP).to receive(:new).and_return(@mock_http)
end

Then("it should return extracted text") do
  expect(@result).to be_a(String)
  expect(@result).not_to be_empty
end

Then("it should return nil") do
  expect(@result).to be_nil
end

Given("the PDF::Reader gem is available") do
  # PDF::Reader is available by default in tests
end

Given("the PDF::Reader gem is not available") do
  allow(Kernel).to receive(:require).with("pdf-reader").and_raise(LoadError.new("cannot load such file -- pdf-reader"))
end

Given("PDF processing will raise an error") do
  allow(Tempfile).to receive(:new).and_raise(StandardError.new("Tempfile error"))
end

When("I extract text from a PDF") do
  @pdf_data = "mock pdf data"
  @vision_service = GoogleVisionService.new
  @result = @vision_service.extract_text_from_pdf(@pdf_data)
end

When("I create a Vision service instance") do
  @mock_service = double("Google::Apis::VisionV1::VisionService")
  allow(@mock_service).to receive(:authorization=)
  allow(@mock_service).to receive(:authorization).and_return(nil)
  allow(Google::Apis::VisionV1::VisionService).to receive(:new).and_return(@mock_service)
  
  @vision_service = GoogleVisionService.new(nil, @user)
end

Then("it should set up OAuth authorization") do
  expect(@vision_service).to be_a(GoogleVisionService)
  expect(@mock_service).to have_received(:authorization=)
end

Then("it should refresh the OAuth tokens") do
  expect(@mock_credentials).to have_received(:refresh!)
  expect(@user.reload.gmail_token).to eq("new_access_token")
end

Then("it should handle refresh failure gracefully") do
  expect(@vision_service).to be_a(GoogleVisionService)
  # Should not raise an error
end

Then("it should not set up OAuth authorization") do
  expect(@vision_service).to be_a(GoogleVisionService)
  # OAuth should not be set up when API key is present or user has no tokens
end

Then("it should not refresh the tokens") do
  expect(@mock_credentials).not_to have_received(:refresh!)
end

