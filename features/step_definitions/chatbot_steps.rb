Given("I am a signed in user") do
  @current_user = User.create!(
    email: 'test@example.com',
    password: 'password123',
    password_confirmation: 'password123'
  )
  # Sign in using Capybara
  visit '/users/sign_in'
  begin
    fill_in 'Email', with: 'test@example.com'
    fill_in 'Password', with: 'password123'
    click_button 'Log in'
  rescue Capybara::ElementNotFound
    # Fallback: try alternative field names
    fill_in 'user_email', with: 'test@example.com' if page.has_field?('user_email')
    fill_in 'user_password', with: 'password123' if page.has_field?('user_password')
    click_button 'Sign in' if page.has_button?('Sign in')
  end
  # Ensure we're authenticated for API requests
  # The session should be maintained by Capybara
end

Given("I am not signed in") do
  @current_user = nil
  # Clear any existing session
  Capybara.reset_sessions!
  # Visit a page to establish a new session
  visit '/'
end

Given("the AI service is configured") do
  @mock_ai_service = instance_double(AiService)
  @mock_client = double("client")
  allow(@mock_ai_service).to receive(:instance_variable_get).with(:@client).and_return(@mock_client)
  allow(@mock_ai_service).to receive(:answer_warranty_question).and_return("This is a test answer about warranties.")
  allow(AiService).to receive(:new).and_return(@mock_ai_service)
end

Given("the AI service is not configured") do
  @mock_ai_service = instance_double(AiService)
  allow(@mock_ai_service).to receive(:instance_variable_get).with(:@client).and_return(nil)
  allow(AiService).to receive(:new).and_return(@mock_ai_service)
end

Given("the AI service is configured but returns nil") do
  @mock_ai_service = instance_double(AiService)
  @mock_client = double("client")
  allow(@mock_ai_service).to receive(:instance_variable_get).with(:@client).and_return(@mock_client)
  allow(@mock_ai_service).to receive(:answer_warranty_question).and_return(nil)
  allow(AiService).to receive(:new).and_return(@mock_ai_service)
end

Given("the AI service raises a rate limit error") do
  @mock_ai_service = instance_double(AiService)
  @mock_client = double("client")
  allow(@mock_ai_service).to receive(:instance_variable_get).with(:@client).and_return(@mock_client)
  rate_limit_error = GeminiRateLimitError.new("Rate limit exceeded", 60)
  allow(@mock_ai_service).to receive(:answer_warranty_question).and_raise(rate_limit_error)
  allow(AiService).to receive(:new).and_return(@mock_ai_service)
end

Given("the AI service raises a generic error") do
  @mock_ai_service = instance_double(AiService)
  @mock_client = double("client")
  allow(@mock_ai_service).to receive(:instance_variable_get).with(:@client).and_return(@mock_client)
  error = StandardError.new("Generic error occurred")
  error.set_backtrace(["line 1", "line 2", "line 3"])
  allow(@mock_ai_service).to receive(:answer_warranty_question).and_raise(error)
  allow(AiService).to receive(:new).and_return(@mock_ai_service)
  allow(Rails.logger).to receive(:error)
end

Given("the AI service raises an error with rate limit keywords") do
  @mock_ai_service = instance_double(AiService)
  @mock_client = double("client")
  allow(@mock_ai_service).to receive(:instance_variable_get).with(:@client).and_return(@mock_client)
  error = StandardError.new("429 rate limit quota exceeded")
  error.set_backtrace(["line 1", "line 2", "line 3"])
  allow(@mock_ai_service).to receive(:answer_warranty_question).and_raise(error)
  allow(AiService).to receive(:new).and_return(@mock_ai_service)
  allow(Rails.logger).to receive(:error)
end

Given("the Google Search service is available") do
  @mock_search_service = instance_double(GoogleSearchService)
  allow(@mock_search_service).to receive(:search_warranty_question).and_return([
    { title: "Test Result 1", link: "http://example.com/1", snippet: "Snippet 1" },
    { title: "Test Result 2", link: "http://example.com/2", snippet: "Snippet 2" }
  ])
  allow(GoogleSearchService).to receive(:new).and_return(@mock_search_service)
end

Given("the Google Search service fails") do
  @mock_search_service = instance_double(GoogleSearchService)
  allow(@mock_search_service).to receive(:search_warranty_question).and_raise(StandardError.new("Search service unavailable"))
  allow(GoogleSearchService).to receive(:new).and_return(@mock_search_service)
end

Given("the Google Search service raises an exception") do
  @mock_search_service = instance_double(GoogleSearchService)
  allow(@mock_search_service).to receive(:search_warranty_question).and_raise(StandardError.new("Search service unavailable"))
  allow(GoogleSearchService).to receive(:new).and_return(@mock_search_service)
  allow(Rails.logger).to receive(:warn)
end

Given("the Google Search service returns nil") do
  @mock_search_service = instance_double(GoogleSearchService)
  allow(@mock_search_service).to receive(:search_warranty_question).and_return(nil)
  allow(GoogleSearchService).to receive(:new).and_return(@mock_search_service)
end

Given("the Google Search service returns {int} results") do |count|
  @mock_search_service = instance_double(GoogleSearchService)
  results = (1..count).map do |i|
    { title: "Result #{i}", link: "http://example.com/#{i}", snippet: "Snippet #{i}" }
  end
  allow(@mock_search_service).to receive(:search_warranty_question).and_return(results)
  allow(GoogleSearchService).to receive(:new).and_return(@mock_search_service)
end

Given("the AI service raises a rate limit error with retry delay of {int} seconds") do |delay|
  @mock_ai_service = instance_double(AiService)
  @mock_client = double("client")
  allow(@mock_ai_service).to receive(:instance_variable_get).with(:@client).and_return(@mock_client)
  rate_limit_error = GeminiRateLimitError.new("Rate limit exceeded", delay)
  allow(@mock_ai_service).to receive(:answer_warranty_question).and_raise(rate_limit_error)
  allow(AiService).to receive(:new).and_return(@mock_ai_service)
  allow(Rails.logger).to receive(:error)
end

Given("the AI service raises a rate limit error without retry delay") do
  @mock_ai_service = instance_double(AiService)
  @mock_client = double("client")
  allow(@mock_ai_service).to receive(:instance_variable_get).with(:@client).and_return(@mock_client)
  rate_limit_error = GeminiRateLimitError.new("Rate limit exceeded", nil)
  allow(@mock_ai_service).to receive(:answer_warranty_question).and_raise(rate_limit_error)
  allow(AiService).to receive(:new).and_return(@mock_ai_service)
  allow(Rails.logger).to receive(:error)
end

Given("the AI service raises an error with message containing {string}") do |keyword|
  @mock_ai_service = instance_double(AiService)
  @mock_client = double("client")
  allow(@mock_ai_service).to receive(:instance_variable_get).with(:@client).and_return(@mock_client)
  error = StandardError.new("Error with #{keyword} in message")
  error.set_backtrace(["line 1", "line 2", "line 3"])
  allow(@mock_ai_service).to receive(:answer_warranty_question).and_raise(error)
  allow(AiService).to receive(:new).and_return(@mock_ai_service)
  allow(Rails.logger).to receive(:error)
end

When("I send a POST request to {string} with question {string}") do |path, question|
  # Use Capybara's driver to make POST request
  # The session should maintain authentication if user is signed in
  page.driver.post(path, { question: question })
end

When("I send a POST request to {string} without question parameter") do |path|
  # Use Capybara's driver to make POST request without question
  page.driver.post(path, {})
end

Then("I should receive a JSON response with status {int}") do |status_code|
  # Get the response from the last request
  # For Rack::Test driver, we can access last_response
  if page.driver.respond_to?(:last_response)
    response = page.driver.last_response
    expect(response.status).to eq(status_code)
    # Check if response is JSON (might be HTML for redirects)
    if response.headers['Content-Type'] && status_code != 302
      expect(response.headers['Content-Type']).to include('application/json')
    end
    @last_response_body = response.body
  else
    # Fallback: use page.status_code and page.body
    expect(page.status_code).to eq(status_code)
    @last_response_body = page.body
    if status_code != 302 && page.response_headers['Content-Type']
      expect(page.response_headers['Content-Type']).to include('application/json')
    end
  end
end

Then("the response should contain an {string} field") do |field_name|
  json_response = JSON.parse(@last_response_body || page.body)
  expect(json_response).to have_key(field_name)
end

Then("the response should contain a {string} field") do |field_name|
  json_response = JSON.parse(@last_response_body || page.body)
  expect(json_response).to have_key(field_name)
end

Then("the response should contain error {string}") do |error_message|
  json_response = JSON.parse(@last_response_body || page.body)
  expect(json_response['error']).to eq(error_message)
end

Then("the response should contain error about chatbot not being configured") do
  json_response = JSON.parse(@last_response_body || page.body)
  expect(json_response['error']).to include("Chatbot is not configured")
  expect(json_response['error']).to include("Gemini API key")
end

Then("the response should contain an empty {string} array") do |field_name|
  json_response = JSON.parse(@last_response_body || page.body)
  expect(json_response[field_name]).to eq([])
end

Then("the response should contain error about unable to generate answer") do
  json_response = JSON.parse(@last_response_body || page.body)
  expect(json_response['error']).to include("Unable to generate an answer")
end

Then("the response should contain error about rate limiting") do
  json_response = JSON.parse(@last_response_body || page.body)
  expect(json_response['error']).to include("rate")
end

Then("the response should contain an error message") do
  json_response = JSON.parse(@last_response_body || page.body)
  expect(json_response).to have_key('error')
  expect(json_response['error']).to be_a(String)
  expect(json_response['error']).not_to be_empty
end

Then("I should be redirected to sign in") do
  # Check for redirect status
  if page.driver.respond_to?(:last_response)
    response = page.driver.last_response
    expect(response.status).to eq(302)
    location = response.headers['Location'] || response.headers['location']
    expect(location).to include('/users/sign_in')
  else
    expect(page.status_code).to eq(302)
    location = page.response_headers['Location'] || page.response_headers['location']
    expect(location).to include('/users/sign_in')
  end
end

Then("it should log a warning about web search being unavailable") do
  expect(Rails.logger).to have_received(:warn).with(/Web search unavailable/)
end

Then("the response should contain a {string} field with at most {int} items") do |field_name, max_items|
  json_response = JSON.parse(@last_response_body || page.body)
  expect(json_response).to have_key(field_name)
  expect(json_response[field_name]).to be_an(Array)
  expect(json_response[field_name].length).to be <= max_items
end

Then("the error message should include retry delay information") do
  json_response = JSON.parse(@last_response_body || page.body)
  expect(json_response['error']).to include("Please try again in about")
  expect(json_response['error']).to include("seconds")
end

Then("the error message should not include retry delay information") do
  json_response = JSON.parse(@last_response_body || page.body)
  expect(json_response['error']).not_to include("Please try again in about")
end

Then("it should log a rate limit error") do
  expect(Rails.logger).to have_received(:error).with(/Chatbot rate limit error/)
end

Then("it should log the error message") do
  expect(Rails.logger).to have_received(:error).with(/Chatbot error/)
end

Then("it should log the error backtrace") do
  expect(Rails.logger).to have_received(:error).at_least(:once)
  # The backtrace is logged as a separate error call
  expect(Rails.logger).to have_received(:error).at_least(:twice)
end

Given("the AI service is configured with client present") do
  @mock_ai_service = instance_double(AiService)
  @mock_client = double("client")
  allow(@mock_ai_service).to receive(:instance_variable_get).with(:@client).and_return(@mock_client)
  allow(@mock_ai_service).to receive(:answer_warranty_question).and_return("This is a test answer about warranties.")
  allow(AiService).to receive(:new).and_return(@mock_ai_service)
end

Given("the AI service raises a rate limit error during initialization with retry delay of {int} seconds") do |delay|
  rate_limit_error = GeminiRateLimitError.new("Rate limit exceeded", delay)
  allow(AiService).to receive(:new).and_raise(rate_limit_error)
  allow(Rails.logger).to receive(:error)
end

Given("the AI service raises a rate limit error during initialization without retry delay") do
  rate_limit_error = GeminiRateLimitError.new("Rate limit exceeded", nil)
  allow(AiService).to receive(:new).and_raise(rate_limit_error)
  allow(Rails.logger).to receive(:error)
end

Given("the AI service raises a generic error during initialization with message containing {string}") do |keyword|
  error = StandardError.new("Error with #{keyword} in message")
  error.set_backtrace(["line 1", "line 2", "line 3"])
  allow(AiService).to receive(:new).and_raise(error)
  allow(Rails.logger).to receive(:error)
end

Given("the AI service raises a generic error during initialization with message {string}") do |message|
  error = StandardError.new(message)
  error.set_backtrace(["line 1", "line 2", "line 3"])
  allow(AiService).to receive(:new).and_raise(error)
  allow(Rails.logger).to receive(:error)
end

Then("the error message should include {string}") do |text|
  json_response = JSON.parse(@last_response_body || page.body)
  expect(json_response['error']).to include(text)
end

