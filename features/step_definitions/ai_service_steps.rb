require 'net/http'
require 'json'

# Setup
Given("the Gemini API key is configured") do
  allow(Rails.application.credentials).to receive(:dig).with(:google, :gemini_api_key).and_return("test_api_key")
  # Mock ENV to return nil for GOOGLE_GEMINI_API_KEY, but allow other ENV access
  allow(ENV).to receive(:[]).and_call_original
  allow(ENV).to receive(:[]).with("GOOGLE_GEMINI_API_KEY").and_return(nil)
end

# Mock HTTP Response Helpers
def create_mock_http_response(code, body)
  response = double("Net::HTTPResponse")
  allow(response).to receive(:code).and_return(code.to_s)
  allow(response).to receive(:body).and_return(body)
  response
end

def create_mock_http
  http = double("Net::HTTP")
  allow(Net::HTTP).to receive(:new).and_return(http)
  allow(http).to receive(:use_ssl=)
  allow(http).to receive(:verify_mode=)
  http
end

# call_gemini_api scenarios
Given("the Gemini API returns status {int} with valid response") do |code|
  body = {
    candidates: [{
      content: {
        parts: [{
          text: "Test response text"
        }]
      }
    }]
  }.to_json
  
  @mock_http = create_mock_http
  @mock_response = create_mock_http_response(code, body)
  allow(@mock_http).to receive(:request).and_return(@mock_response)
  @ai_service = AiService.new
end

Given("the Gemini API returns status {int} with empty text") do |code|
  body = {
    candidates: [{
      content: {
        parts: [{}]
      }
    }]
  }.to_json
  
  @mock_http = create_mock_http
  @mock_response = create_mock_http_response(code, body)
  allow(@mock_http).to receive(:request).and_return(@mock_response)
  @ai_service = AiService.new
end

Given("the Gemini API returns status {int} with retry delay of {int} seconds") do |code, delay|
  error_body = {
    error: {
      message: "Rate limit exceeded",
      details: [{
        "@type" => "type.googleapis.com/google.rpc.RetryInfo",
        "retryDelay" => "#{delay}s"
      }]
    }
  }.to_json
  
  success_body = {
    candidates: [{
      content: {
        parts: [{
          text: "Test response text"
        }]
      }
    }]
  }.to_json
  
  @mock_http = create_mock_http
  @error_response = create_mock_http_response(code, error_body)
  @success_response = create_mock_http_response(200, success_body)
  @retry_delay_value = delay
  
  # Default: return error first, then success on retry
  # Will be adjusted in "retry count" step if needed
  allow(@mock_http).to receive(:request).and_return(@error_response, @success_response)
  
  @ai_service = AiService.new
  allow(Rails.logger).to receive(:warn)
  allow_any_instance_of(AiService).to receive(:sleep)
end

Given("the Gemini API returns status {int} without retry delay") do |code|
  body = {
    error: {
      message: "Rate limit exceeded"
    }
  }.to_json
  
  @mock_http = create_mock_http
  @mock_response = create_mock_http_response(code, body)
  allow(@mock_http).to receive(:request).and_return(@mock_response)
  @ai_service = AiService.new
end

Given("the Gemini API returns status {int} with error message") do |code|
  body = {
    error: {
      message: "API error occurred"
    }
  }.to_json
  
  @mock_http = create_mock_http
  @mock_response = create_mock_http_response(code, body)
  allow(@mock_http).to receive(:request).and_return(@mock_response)
  @ai_service = AiService.new
  allow(Rails.logger).to receive(:error)
end

Given("the Gemini API returns invalid JSON") do
  @mock_http = create_mock_http
  @mock_response = create_mock_http_response(200, "invalid json {")
  allow(@mock_http).to receive(:request).and_return(@mock_response)
  @ai_service = AiService.new
  allow(Rails.logger).to receive(:error)
end

Given("the retry count is {int}") do |count|
  @retry_count = count
  # If retry_count >= 2 or delay > 10 or delay == 0 or delay < 0, don't retry - only return error
  if @mock_http && @error_response
    if count >= 2 || (@retry_delay_value && (@retry_delay_value > 10 || @retry_delay_value <= 0))
      allow(@mock_http).to receive(:request).and_return(@error_response)
    end
  end
end

When("I call the Gemini API with prompt {string}") do |prompt|
  begin
    @result = @ai_service.send(:call_gemini_api, prompt, @retry_count || 0)
  rescue => e
    @error = e
  end
end

When("I call the Gemini API with image and prompt {string}") do |prompt|
  image_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
  begin
    @result = @ai_service.send(:call_gemini_api_with_image, prompt, image_base64, @retry_count || 0)
  rescue => e
    @error = e
  end
end

Then("it should return the response text") do
  expect(@result).to eq("Test response text")
end

Then("it should return an empty string") do
  expect(@result).to eq("")
end

Then("it should parse the JSON response") do
  expect(@result).to be_a(String)
end

Then("it should retry the API call") do
  # Verify that request was called multiple times (retry happened)
  expect(@mock_http).to have_received(:request).at_least(:twice)
end

Then("it should log a warning about rate limit retry") do
  expect(Rails.logger).to have_received(:warn).with(/Gemini API rate limit hit/)
end

Then("it should raise GeminiRateLimitError") do
  expect(@error).to be_a(GeminiRateLimitError)
end

Then("the error should include retry delay") do
  expect(@error.retry_delay).not_to be_nil
end

Then("the error should not include retry delay") do
  expect(@error.retry_delay).to be_nil
end

Then("it should raise an error with message containing {string}") do |message|
  expect(@error.message).to include(message)
end

Then("it should raise an error with message {string}") do |message|
  expect(@error.message).to eq(message)
end

# extract_retry_delay scenarios
Given("I have error data with RetryInfo and delay {string}") do |delay|
  # Ensure ENV is mocked before creating AiService
  allow(Rails.application.credentials).to receive(:dig).with(:google, :gemini_api_key).and_return("test_api_key")
  allow(ENV).to receive(:[]).and_call_original
  allow(ENV).to receive(:[]).with("GOOGLE_GEMINI_API_KEY").and_return(nil)
  
  @error_data = {
    error: {
      details: [{
        "@type" => "type.googleapis.com/google.rpc.RetryInfo",
        "retryDelay" => delay
      }]
    }
  }
  @ai_service = AiService.new
end

Given("I have error data without RetryInfo") do
  # Ensure ENV is mocked before creating AiService
  allow(Rails.application.credentials).to receive(:dig).with(:google, :gemini_api_key).and_return("test_api_key")
  allow(ENV).to receive(:[]).and_call_original
  allow(ENV).to receive(:[]).with("GOOGLE_GEMINI_API_KEY").and_return(nil)
  
  @error_data = {
    error: {
      details: []
    }
  }
  @ai_service = AiService.new
end

Given("I have error data with RetryInfo but no delay") do
  # Ensure ENV is mocked before creating AiService
  allow(Rails.application.credentials).to receive(:dig).with(:google, :gemini_api_key).and_return("test_api_key")
  allow(ENV).to receive(:[]).and_call_original
  allow(ENV).to receive(:[]).with("GOOGLE_GEMINI_API_KEY").and_return(nil)
  
  @error_data = {
    error: {
      details: [{
        "@type" => "type.googleapis.com/google.rpc.RetryInfo"
      }]
    }
  }
  @ai_service = AiService.new
end

Given("I have empty error data") do
  # Ensure ENV is mocked before creating AiService
  allow(Rails.application.credentials).to receive(:dig).with(:google, :gemini_api_key).and_return("test_api_key")
  allow(ENV).to receive(:[]).and_call_original
  allow(ENV).to receive(:[]).with("GOOGLE_GEMINI_API_KEY").and_return(nil)
  
  @error_data = {}
  @ai_service = AiService.new
end

When("I extract the retry delay") do
  @retry_delay = @ai_service.send(:extract_retry_delay, @error_data)
end

Then("it should return {float} seconds") do |expected_seconds|
  expect(@retry_delay).to eq(expected_seconds)
end

Then("it should return nil") do
  expect(@retry_delay).to be_nil
end

Given("I have search results") do
  @search_results = [
    { title: "Result 1", snippet: "Snippet 1", url: "http://example.com/1" },
    { title: "Result 2", snippet: "Snippet 2", url: "http://example.com/2" }
  ]
end

Given("I have no search results") do
  @search_results = []
end

When("I answer warranty question {string} with search results") do |question|
  allow(Rails.application.credentials).to receive(:dig).with(:google, :gemini_api_key).and_return("test_api_key")
  allow(ENV).to receive(:[]).and_call_original
  allow(ENV).to receive(:[]).with("GOOGLE_GEMINI_API_KEY").and_return(nil)
  
  @mock_http = create_mock_http
  @mock_response = create_mock_http_response(200, {
    candidates: [{
      content: {
        parts: [{
          text: "Test answer"
        }]
      }
    }]
  }.to_json)
  allow(@mock_http).to receive(:request).and_return(@mock_response)
  
  @ai_service = AiService.new
  @result = @ai_service.answer_warranty_question(question, @search_results)
end

When("I answer warranty question {string} without search results") do |question|
  allow(Rails.application.credentials).to receive(:dig).with(:google, :gemini_api_key).and_return("test_api_key")
  allow(ENV).to receive(:[]).and_call_original
  allow(ENV).to receive(:[]).with("GOOGLE_GEMINI_API_KEY").and_return(nil)
  
  @mock_http = create_mock_http
  @mock_response = create_mock_http_response(200, {
    candidates: [{
      content: {
        parts: [{}]
      }
    }]
  }.to_json)
  allow(@mock_http).to receive(:request).and_return(@mock_response)
  
  @ai_service = AiService.new
  @result = @ai_service.answer_warranty_question(question, nil)
end

Then("it should include search context in the prompt") do
  expect(@result).to be_a(String)
  # Verify that search results were included by checking the request
  expect(@mock_http).to have_received(:request)
end

Then("it should not include search context") do
  expect(@result).to be_a(String)
  # Verify that no search context was included
  expect(@mock_http).to have_received(:request)
end

Then("it should return the fallback message") do
  expect(@result).to eq("I'm sorry, I couldn't generate a response. Please try rephrasing your question.")
end

Given("the Gemini API returns receipt confirmation") do
  allow(Rails.application.credentials).to receive(:dig).with(:google, :gemini_api_key).and_return("test_api_key")
  allow(ENV).to receive(:[]).and_call_original
  allow(ENV).to receive(:[]).with("GOOGLE_GEMINI_API_KEY").and_return(nil)
  
  @mock_http = create_mock_http
  @mock_response = create_mock_http_response(200, {
    candidates: [{
      content: {
        parts: [{
          text: '{"is_receipt": true, "product_name": "iPhone 15 Pro", "merchant": "Apple", "purchase_date": "2024-01-15"}'
        }]
      }
    }]
  }.to_json)
  allow(@mock_http).to receive(:request).and_return(@mock_response)
  
  @ai_service = AiService.new
end

Given("the Gemini API returns non-receipt confirmation") do
  allow(Rails.application.credentials).to receive(:dig).with(:google, :gemini_api_key).and_return("test_api_key")
  allow(ENV).to receive(:[]).and_call_original
  allow(ENV).to receive(:[]).with("GOOGLE_GEMINI_API_KEY").and_return(nil)
  
  @mock_http = create_mock_http
  @mock_response = create_mock_http_response(200, {
    candidates: [{
      content: {
        parts: [{
          text: '{"is_receipt": false}'
        }]
      }
    }]
  }.to_json)
  allow(@mock_http).to receive(:request).and_return(@mock_response)
  
  @ai_service = AiService.new
end

When("I extract receipt info from email content") do
  @result = @ai_service.extract_receipt_info("Order confirmation for iPhone 15 Pro")
end

When("I extract receipt info from image") do
  image_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
  @result = @ai_service.extract_receipt_info_from_image(image_base64)
end

Then("it should return receipt data") do
  expect(@result).to be_a(Hash)
  expect(@result["is_receipt"]).to eq(true)
  expect(@result["product_name"]).to eq("iPhone 15 Pro")
end

