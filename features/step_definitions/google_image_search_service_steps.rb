require 'net/http'
require 'json'

Given("the Google Image Search service is available") do
end


When("I create a GoogleImageSearchService instance without credentials") do
  allow(Rails.application.credentials).to receive(:dig).and_return(nil)
  allow(ENV).to receive(:[]).and_call_original
  allow(ENV).to receive(:[]).with("GOOGLE_SEARCH_API_KEY").and_return(nil)
  allow(ENV).to receive(:[]).with("GOOGLE_VISION_API_KEY").and_return(nil)
  allow(ENV).to receive(:[]).with("GOOGLE_GEMINI_API_KEY").and_return(nil)
  allow(ENV).to receive(:[]).with("GOOGLE_SEARCH_ENGINE_ID").and_return(nil)
  @service = GoogleImageSearchService.new
end

When("I create a GoogleImageSearchService instance") do
  @service = GoogleImageSearchService.new
end

Then("the image search service should be initialized without API key") do
  expect(@service.instance_variable_get(:@api_key)).to be_nil
  expect(@service.instance_variable_get(:@search_engine_id)).to be_nil
end

Then("the image search service should be initialized with API key and search engine ID") do
  expect(@service.instance_variable_get(:@api_key)).to eq("test_api_key")
  expect(@service.instance_variable_get(:@search_engine_id)).to eq("test_engine_id")
end

Given("the Google Image Search API returns valid product image results") do
  @mock_response = double("Net::HTTPResponse")
  allow(@mock_response).to receive(:code).and_return("200")
  allow(@mock_response).to receive(:body).and_return({
    "items" => [
      {
        "title" => "iPhone 15 Product Photo",
        "snippet" => "Apple iPhone 15 product image",
        "link" => "https://example.com/iphone15.jpg",
        "image" => { "width" => 500, "height" => 500 }
      }
    ]
  }.to_json)
  
  @mock_http = double("Net::HTTP")
  allow(@mock_http).to receive(:use_ssl=)
  allow(@mock_http).to receive(:verify_mode=)
  allow(@mock_http).to receive(:request).and_return(@mock_response)
  allow(Net::HTTP).to receive(:new).and_return(@mock_http)
end

Given("the Google Image Search API returns valid logo results") do
  @mock_response = double("Net::HTTPResponse")
  allow(@mock_response).to receive(:code).and_return("200")
  allow(@mock_response).to receive(:body).and_return({
    "items" => [
      {
        "title" => "Amazon Logo",
        "snippet" => "Amazon company logo",
        "link" => "https://amazon.com/logo.png",
        "image" => { "width" => 200, "height" => 200 }
      }
    ]
  }.to_json)
  
  @mock_http = double("Net::HTTP")
  allow(@mock_http).to receive(:use_ssl=)
  allow(@mock_http).to receive(:verify_mode=)
  allow(@mock_http).to receive(:request).and_return(@mock_response)
  allow(Net::HTTP).to receive(:new).and_return(@mock_http)
end

Given("the Google Image Search API returns an error") do
  @mock_response = double("Net::HTTPResponse")
  allow(@mock_response).to receive(:code).and_return("400")
  allow(@mock_response).to receive(:body).and_return("Error message")
  
  @mock_http = double("Net::HTTP")
  allow(@mock_http).to receive(:use_ssl=)
  allow(@mock_http).to receive(:verify_mode=)
  allow(@mock_http).to receive(:request).and_return(@mock_response)
  allow(Net::HTTP).to receive(:new).and_return(@mock_http)
  allow(Rails.logger).to receive(:error)
end

When("I search for product image {string} with merchant {string}") do |product_name, merchant|
  @service = GoogleImageSearchService.new
  @result = @service.search_product_image(product_name, merchant)
end

When("I search for product image {string}") do |product_name|
  @service = GoogleImageSearchService.new
  @result = @service.search_product_image(product_name)
end

When("I search for merchant logo {string}") do |merchant|
  @service = GoogleImageSearchService.new
  @result = @service.search_merchant_logo(merchant)
end

Then("it should return a valid image URL") do
  expect(@result).to be_a(String)
  expect(@result).to match(/^https?:\/\//)
end

Then("it should return a valid logo URL") do
  expect(@result).to be_a(String)
  expect(@result).to match(/^https?:\/\//)
end

Then("the image search should return nil") do
  expect(@result).to be_nil
end

Then("the image search should log the error") do
  expect(Rails.logger).to have_received(:error)
end

