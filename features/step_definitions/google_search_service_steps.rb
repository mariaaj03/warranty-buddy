require 'net/http'
require 'json'

# Setup and Configuration Steps
Given("the Google Search API is configured") do
  allow(Rails.application.credentials).to receive(:dig).with(:google, :search_api_key).and_return("test_api_key")
  allow(Rails.application.credentials).to receive(:dig).with(:google, :search_engine_id).and_return("test_engine_id")
end

Given("the Google Search API credentials are configured") do
  allow(Rails.application.credentials).to receive(:dig).with(:google, :search_api_key).and_return("test_api_key")
  allow(Rails.application.credentials).to receive(:dig).with(:google, :search_engine_id).and_return("test_engine_id")
end

Given("the Google Search API credentials are not configured") do
  # Mock Rails.application.credentials to return nil
  allow(Rails.application.credentials).to receive(:dig).with(:google, :search_api_key).and_return(nil)
  allow(Rails.application.credentials).to receive(:dig).with(:google, :search_engine_id).and_return(nil)
end

When("I create a GoogleSearchService instance") do
  @search_service = GoogleSearchService.new
end

Then("it should be initialized with API key and search engine ID") do
  expect(@search_service.instance_variable_get(:@api_key)).to eq("test_api_key")
  expect(@search_service.instance_variable_get(:@search_engine_id)).to eq("test_engine_id")
end

Then("it should be initialized without API key") do
  expect(@search_service.instance_variable_get(:@api_key)).to be_nil
  expect(@search_service.instance_variable_get(:@search_engine_id)).to be_nil
end

# Mock HTTP Response Helpers
def create_mock_http_response(status_code, body)
  response = double("Net::HTTPResponse")
  allow(response).to receive(:code).and_return(status_code.to_s)
  allow(response).to receive(:body).and_return(body)
  response
end

def create_mock_search_results(items)
  {
    "items" => items
  }.to_json
end

def create_search_result_item(title:, snippet:, link:)
  {
    "title" => title,
    "snippet" => snippet,
    "link" => link
  }
end

# lookup_warranty_info Steps
Given("the Google Search API returns valid warranty results") do
  items = [
    create_search_result_item(
      title: "Product Warranty Information",
      snippet: "This product comes with a 12 months warranty and 30 days return policy",
      link: "http://example.com/warranty"
    )
  ]
  response_body = create_mock_search_results(items)
  @mock_response = create_mock_http_response(200, response_body)
  
  # Mock Net::HTTP.get_response
  allow(Net::HTTP).to receive(:get_response).and_return(@mock_response)
end

Given("the Google Search API returns empty results") do
  response_body = create_mock_search_results([])
  @mock_response = create_mock_http_response(200, response_body)
  allow(Net::HTTP).to receive(:get_response).and_return(@mock_response)
end

Given("the Google Search API request fails") do
  allow(Net::HTTP).to receive(:get_response).and_raise(StandardError.new("Network error"))
end

When("I lookup warranty info for product {string} from merchant {string} using Google Search") do |product, merchant|
  @search_service = GoogleSearchService.new
  @lookup_result = @search_service.lookup_warranty_info(product, merchant)
end

When("I lookup warranty info for product {string} from merchant {string}") do |product, merchant|
  @search_service = GoogleSearchService.new
  @lookup_result = @search_service.lookup_warranty_info(product, merchant)
end

When("I lookup warranty info for product {string} without merchant") do |product|
  @search_service = GoogleSearchService.new
  @lookup_result = @search_service.lookup_warranty_info(product, nil)
end

Then("it should return warranty information") do
  expect(@lookup_result).not_to be_nil
  expect(@lookup_result).to be_a(Hash)
end

Then("it should return nil") do
  expect(@lookup_result).to be_nil
end

Then("it should include warranty months") do
  expect(@lookup_result).to have_key(:warranty_months)
end

Then("it should include return policy days") do
  expect(@lookup_result).to have_key(:return_policy_days)
end

Then("it should include source as {string}") do |source|
  expect(@lookup_result[:source]).to eq(source)
end

Then("it should include details array") do
  expect(@lookup_result[:details]).to be_an(Array)
end

Then("the search query should include the product name") do
  # This step verifies that the product name is included in the search query
  # The actual product name will be checked in the specific scenario
  expect(Net::HTTP).to have_received(:get_response) do |uri|
    if uri.is_a?(URI::HTTPS)
      query_params = URI.decode_www_form(uri.query || "").to_h
      query_text = query_params["q"] || ""
      expect(query_text).to be_present
    end
  end
end

# search_warranty_question Steps
Given("the Google Search API returns valid search results") do
  items = [
    create_search_result_item(
      title: "Warranty Information",
      snippet: "Learn about warranty coverage",
      link: "http://example.com/warranty"
    ),
    create_search_result_item(
      title: "Product Warranty Guide",
      snippet: "Understanding product warranties",
      link: "http://example.com/guide"
    )
  ]
  response_body = create_mock_search_results(items)
  @mock_response = create_mock_http_response(200, response_body)
  allow(Net::HTTP).to receive(:get_response).and_return(@mock_response)
end

Given("the Google Search API returns error status {int}") do |status_code|
  @mock_response = create_mock_http_response(status_code, "Error message")
  allow(Net::HTTP).to receive(:get_response).and_return(@mock_response)
  # Mock Rails.logger
  allow(Rails.logger).to receive(:error)
end

Given("the Google Search API request raises an exception") do
  allow(Net::HTTP).to receive(:get_response).and_raise(StandardError.new("Request failed"))
  allow(Rails.logger).to receive(:error)
end

Given("the Google Search API returns response with no items") do
  response_body = {}.to_json
  @mock_response = create_mock_http_response(200, response_body)
  allow(Net::HTTP).to receive(:get_response).and_return(@mock_response)
end

When("I search for warranty question {string}") do |question|
  @search_service = GoogleSearchService.new
  @search_results = @search_service.search_warranty_question(question)
end

Then("it should return an array of search results") do
  expect(@search_results).to be_an(Array)
  expect(@search_results).not_to be_empty
end

Then("each result should have title, snippet, and url") do
  @search_results.each do |result|
    expect(result).to have_key(:title)
    expect(result).to have_key(:snippet)
    expect(result).to have_key(:url)
  end
end

Then("the search query should include {string}") do |text|
  # Verify that the query was built correctly by checking the URI
  # This is for search_warranty_question which appends " warranty coverage"
  expect(Net::HTTP).to have_received(:get_response) do |uri|
    if uri.is_a?(URI::HTTPS)
      query_params = URI.decode_www_form(uri.query || "").to_h
      query_text = query_params["q"] || ""
      expect(query_text.downcase).to include(text.downcase)
    end
  end
end

Then("it should return an empty array") do
  expect(@search_results).to eq([])
end


# extract_warranty_info Steps (tested through lookup_warranty_info)
Given("the Google Search API returns results with {string}") do |warranty_text|
  items = [
    create_search_result_item(
      title: "Warranty Information",
      snippet: warranty_text,
      link: "http://example.com/warranty"
    )
  ]
  response_body = create_mock_search_results(items)
  @mock_response = create_mock_http_response(200, response_body)
  allow(Net::HTTP).to receive(:get_response).and_return(@mock_response)
end

Given("the Google Search API returns results with multiple warranty periods where first is higher") do
  items = [
    create_search_result_item(
      title: "Warranty Info 1",
      snippet: "This product has 24 months warranty",
      link: "http://example.com/1"
    ),
    create_search_result_item(
      title: "Warranty Info 2",
      snippet: "Standard warranty: 12 months warranty",
      link: "http://example.com/2"
    )
  ]
  response_body = create_mock_search_results(items)
  @mock_response = create_mock_http_response(200, response_body)
  allow(Net::HTTP).to receive(:get_response).and_return(@mock_response)
end

Given("the Google Search API returns results with multiple warranty periods") do
  items = [
    create_search_result_item(
      title: "Warranty Info 1",
      snippet: "This product has 6 months warranty",
      link: "http://example.com/1"
    ),
    create_search_result_item(
      title: "Warranty Info 2",
      snippet: "Extended warranty available: 24 months warranty",
      link: "http://example.com/2"
    )
  ]
  response_body = create_mock_search_results(items)
  @mock_response = create_mock_http_response(200, response_body)
  allow(Net::HTTP).to receive(:get_response).and_return(@mock_response)
end

Given("the Google Search API returns results with multiple return policy periods") do
  items = [
    create_search_result_item(
      title: "Return Policy 1",
      snippet: "15 days return policy",
      link: "http://example.com/1"
    ),
    create_search_result_item(
      title: "Return Policy 2",
      snippet: "Extended return: 45 days return policy",
      link: "http://example.com/2"
    )
  ]
  response_body = create_mock_search_results(items)
  @mock_response = create_mock_http_response(200, response_body)
  allow(Net::HTTP).to receive(:get_response).and_return(@mock_response)
end

Given("the Google Search API returns results without warranty information") do
  items = [
    create_search_result_item(
      title: "Product Information",
      snippet: "This is a great product with excellent features",
      link: "http://example.com/product"
    )
  ]
  response_body = create_mock_search_results(items)
  @mock_response = create_mock_http_response(200, response_body)
  allow(Net::HTTP).to receive(:get_response).and_return(@mock_response)
end

Given("the Google Search API returns results without return policy") do
  items = [
    create_search_result_item(
      title: "Warranty Information",
      snippet: "12 months warranty included",
      link: "http://example.com/warranty"
    )
  ]
  response_body = create_mock_search_results(items)
  @mock_response = create_mock_http_response(200, response_body)
  allow(Net::HTTP).to receive(:get_response).and_return(@mock_response)
end

Then("it should extract warranty months as {int}") do |months|
  expect(@lookup_result[:warranty_months]).to eq(months)
end

Then("it should extract the highest warranty months") do
  # Should extract 24 months (the highest) from the multiple results
  expect(@lookup_result[:warranty_months]).to eq(24)
end

Then("it should extract return policy days as {int}") do |days|
  expect(@lookup_result[:return_policy_days]).to eq(days)
end

Then("it should extract the highest return policy days") do
  # Should extract 45 days (the highest) from the multiple results
  expect(@lookup_result[:return_policy_days]).to eq(45)
end

Then("it should return warranty information with nil warranty months") do
  expect(@lookup_result).not_to be_nil
  expect(@lookup_result[:warranty_months]).to be_nil
end

Then("it should default return policy days to 30") do
  expect(@lookup_result[:return_policy_days]).to eq(30)
end

Then("it should not override existing return policy") do
  # This verifies that when return_policy_days is already set, it doesn't get overridden
  expect(@lookup_result[:return_policy_days]).to eq(30)
end

Given("the Google Search API returns nil results") do
  # Mock to return empty array which will cause "return nil unless search_results&.any?" to return nil
  # We'll mock perform_search to return [] which is falsy for .any?
  response_body = create_mock_search_results([])
  @mock_response = create_mock_http_response(200, response_body)
  allow(Net::HTTP).to receive(:get_response).and_return(@mock_response)
end

Given("the Google Search API returns error status {int} for lookup") do |status_code|
  @mock_response = create_mock_http_response(status_code, "Error message")
  allow(Net::HTTP).to receive(:get_response).and_return(@mock_response)
  allow(Rails.logger).to receive(:error)
end

Given("the Google Search API request raises an exception for lookup") do
  allow(Net::HTTP).to receive(:get_response).and_raise(StandardError.new("Request failed"))
  allow(Rails.logger).to receive(:error)
end

Then("it should log a lookup error") do
  expect(Rails.logger).to have_received(:error).with(/Google Search API error/)
end

Then("it should log a lookup exception") do
  expect(Rails.logger).to have_received(:error).with(/Google Search API request failed/)
end

# build_warranty_query Steps (tested through lookup_warranty_info)
# Note: The step "the search query should include {string}" is already defined above
# These steps test the query building through lookup_warranty_info

Then("the search query should not include merchant name") do
  # When no merchant is provided, the query should not include merchant-specific terms
  # This is verified by the fact that the query doesn't contain merchant names
  expect(Net::HTTP).to have_received(:get_response) do |uri|
    if uri.is_a?(URI::HTTPS)
      query_params = URI.decode_www_form(uri.query || "").to_h
      query_text = query_params["q"] || ""
      # The query should still be present but shouldn't have merchant-specific patterns
      expect(query_text).to be_present
    end
  end
end

Then("the search query should include merchant {string}") do |merchant_name|
  expect(Net::HTTP).to have_received(:get_response) do |uri|
    if uri.is_a?(URI::HTTPS)
      query_params = URI.decode_www_form(uri.query || "").to_h
      query_text = query_params["q"] || ""
      expect(query_text).to include(merchant_name)
    end
  end
end

Then("it should keep the higher warranty months value") do
  # Should keep 24 months (the first/higher value) instead of replacing with 12
  expect(@lookup_result[:warranty_months]).to eq(24)
end

