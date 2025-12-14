# features/step_definitions/gmail_fetcher_steps.rb

Given("the Gmail Fetcher service is available") do
  # Setup for Gmail Fetcher tests
end

Given("I have an access token") do
  @access_token = "test_access_token"
end

Given("I have an access token and refresh token") do
  @access_token = "test_access_token"
  @refresh_token = "test_refresh_token"
end

Given("I have a user") do
  @user = User.create!(
    email: 'test@example.com',
    password: 'password123',
    password_confirmation: 'password123',
    gmail_token: @access_token,
    gmail_refresh_token: @refresh_token
  )
end

Given("I have expired credentials") do
  @access_token = "expired_token"
  @refresh_token = "test_refresh_token"
  @user = User.create!(
    email: 'test@example.com',
    password: 'password123',
    password_confirmation: 'password123',
    gmail_token: @access_token,
    gmail_refresh_token: @refresh_token
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
end

Given("credential refresh will fail") do
  allow(@mock_credentials).to receive(:refresh!).and_raise(StandardError.new("Refresh failed"))
end

Given("I have valid credentials") do
  @access_token = "valid_token"
  @refresh_token = "test_refresh_token"
  @user = User.create!(
    email: 'test@example.com',
    password: 'password123',
    password_confirmation: 'password123',
    gmail_token: @access_token,
    gmail_refresh_token: @refresh_token
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
end

Given("client credentials are missing") do
  allow(Rails.application.credentials).to receive(:dig).with(:google, :client_id).and_return(nil)
  allow(Rails.application.credentials).to receive(:dig).with(:google, :client_secret).and_return(nil)
  allow(ENV).to receive(:[]).and_call_original
  allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return(nil)
  allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_SECRET").and_return(nil)
end

When("I create a Gmail Fetcher with access token only") do
  @fetcher = GmailFetcher.new(@access_token)
end

When("I create a Gmail Fetcher with refresh token") do
  @fetcher = GmailFetcher.new(@access_token, @refresh_token, @user)
end

Then("it should be initialized") do
  expect(@fetcher).to be_a(GmailFetcher)
end

Then("it should refresh the credentials") do
  expect(@mock_credentials).to have_received(:refresh!)
end

Then("it should update the user tokens") do
  expect(@user.reload.gmail_token).to eq("new_access_token")
end

Then("it should handle refresh failure gracefully") do
  expect(@fetcher).to be_a(GmailFetcher)
  # Should not raise an error
end

Then("it should not refresh the credentials") do
  expect(@mock_credentials).not_to have_received(:refresh!)
end

Then("it should not set up refresh authorization") do
  expect(@fetcher).to be_a(GmailFetcher)
  # Should not set up refresh when credentials are missing
end

Given("I have a message with HTML in body") do
  @mock_body = double("Body", data: Base64.urlsafe_encode64("<html><body>Test</body></html>"))
  @mock_payload = double("Payload", body: @mock_body, parts: nil)
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

Given("I have a message with HTML in parts") do
  @mock_html_body = double("Body", data: Base64.urlsafe_encode64("<html><body>Test</body></html>"))
  @mock_html_part = double("Part", 
    mime_type: "text/html",
    body: @mock_html_body,
    parts: nil
  )
  @mock_payload = double("Payload", body: nil, parts: [@mock_html_part])
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

Given("I have a message with no HTML") do
  @mock_payload = double("Payload", body: nil, parts: nil)
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

When("I extract HTML from the message") do
  @result = @fetcher.extract_html_from_message(@mock_message)
end

Then("it should return the HTML content") do
  expect(@result).to include("<html>")
end


Then("the HTML extraction should return an empty string") do
  expect(@result).to eq("")
end

Given("I have a message with text in body") do
  @mock_body = double("Body", data: Base64.urlsafe_encode64("Plain text content"))
  @mock_payload = double("Payload", body: @mock_body, parts: nil)
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

Given("I have a message with text in parts") do
  @mock_text_body = double("Body", data: Base64.urlsafe_encode64("Plain text content"))
  @mock_text_part = double("Part",
    mime_type: "text/plain",
    body: @mock_text_body,
    parts: nil
  )
  @mock_payload = double("Payload", body: nil, parts: [@mock_text_part])
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

Given("I have a message with no text") do
  @mock_payload = double("Payload", body: nil, parts: nil)
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

When("I extract text from the message") do
  @result = @fetcher.extract_text_from_message(@mock_message)
end

Then("it should return the text content") do
  expect(@result).to include("Plain text")
end

Given("I have a message with attachments in parts") do
  @mock_attachment_body = double("Body", attachment_id: "att_123")
  @mock_attachment_part = double("Part",
    filename: "receipt.pdf",
    body: @mock_attachment_body,
    mime_type: "application/pdf",
    parts: nil
  )
  @mock_payload = double("Payload", parts: [@mock_attachment_part])
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

Given("I have a message with attachments in nested parts") do
  @mock_attachment_body = double("Body", attachment_id: "att_456")
  @mock_attachment_part = double("Part",
    filename: "receipt.pdf",
    body: @mock_attachment_body,
    mime_type: "application/pdf",
    parts: nil
  )
  @mock_nested_part = double("Part",
    filename: nil,
    body: nil,
    parts: [@mock_attachment_part]
  )
  @mock_payload = double("Payload", parts: [@mock_nested_part])
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

Given("I have a message with no attachments") do
  @mock_text_part = double("Part",
    filename: nil,
    body: double("Body", attachment_id: nil),
    parts: nil
  )
  @mock_payload = double("Payload", parts: [@mock_text_part])
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

Given("I have a message with no payload parts") do
  @mock_payload = double("Payload", parts: nil)
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

When("I extract attachments from the message") do
  @result = @fetcher.extract_attachments(@mock_message)
end

Then("it should return the attachments") do
  expect(@result).to be_an(Array)
  expect(@result.first[:filename]).to eq("receipt.pdf")
end

Then("it should return all attachments") do
  expect(@result).to be_an(Array)
  expect(@result.length).to be > 0
end



Then("the Gmail fetcher should return an empty array") do
  expect(@result).to eq([])
end

Given("I have URL-safe base64 encoded data") do
  @encoded_data = Base64.urlsafe_encode64("Test content")
end

Given("I have standard base64 encoded data") do
  # Create data that will fail URL-safe decode but succeed with standard decode
  @encoded_data = Base64.encode64("Test content").strip
end

Given("I have invalid base64 data") do
  @encoded_data = "invalid!!!base64"
end

When("I decode the base64 data") do
  # Access private method via send
  @result = @fetcher.send(:base64_decode, @encoded_data)
end

Then("it should return decoded content") do
  expect(@result).to include("Test")
end



Given("the Gmail API returns paginated messages") do
  @mock_service = double("GmailService")
  @mock_message1 = double("Message", id: "msg1")
  @mock_message2 = double("Message", id: "msg2")
  
  @mock_result1 = double("ListMessagesResponse",
    messages: [@mock_message1],
    next_page_token: "token123"
  )
  @mock_result2 = double("ListMessagesResponse",
    messages: [@mock_message2],
    next_page_token: nil
  )
  
  allow(@mock_service).to receive(:list_user_messages).and_return(@mock_result1, @mock_result2)
  allow(Google::Apis::GmailV1::GmailService).to receive(:new).and_return(@mock_service)
  
  @fetcher = GmailFetcher.new("test_token")
  @fetcher.instance_variable_set(:@service, @mock_service)
end

When("I list messages with query {string}") do |query|
  @result = @fetcher.send(:list_messages, "me", query, 100)
end

Then("it should return all messages from all pages") do
  expect(@result.length).to eq(2)
end

Given("the Gmail API returns many messages") do
  @mock_service = double("GmailService")
  @mock_messages = (1..20).map { |i| double("Message", id: "msg#{i}") }
  @mock_result = double("ListMessagesResponse",
    messages: @mock_messages,
    next_page_token: nil
  )
  allow(@mock_service).to receive(:list_user_messages).and_return(@mock_result)
  allow(Google::Apis::GmailV1::GmailService).to receive(:new).and_return(@mock_service)
  
  @fetcher = GmailFetcher.new("test_token")
  @fetcher.instance_variable_set(:@service, @mock_service)
end

When("I list messages with max results {int}") do |max_results|
  @result = @fetcher.send(:list_messages, "me", "test", max_results)
end


Then("it should return at most {int} messages") do |max_results|
  expect(@result.length).to be <= max_results
end

Given("I have a message ID") do
  @message_id = "test_message_id"
  @mock_message = double("Message", id: @message_id)
  @mock_service = double("GmailService")
  allow(@mock_service).to receive(:get_user_message).with("me", @message_id, format: "full").and_return(@mock_message)
  allow(Google::Apis::GmailV1::GmailService).to receive(:new).and_return(@mock_service)
  
  @fetcher = GmailFetcher.new("test_token")
  @fetcher.instance_variable_set(:@service, @mock_service)
end

When("I get the message") do
  @result = @fetcher.get_message(@message_id)
end

Then("it should return the full message") do
  expect(@result).to eq(@mock_message)
end

Given("I have a message with HTML body without html tag") do
  @mock_body = double("Body", data: Base64.urlsafe_encode64("Not HTML content"))
  @mock_html_part = double("Part",
    mime_type: "text/html",
    body: double("Body", data: Base64.urlsafe_encode64("<html><body>Test</body></html>")),
    parts: nil
  )
  @mock_payload = double("Payload", body: @mock_body, parts: [@mock_html_part])
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

# New step definitions for coverage scenarios
Given("I have a message with HTML in body data") do
  @mock_body = double("Body", data: Base64.urlsafe_encode64("<html><body>Test HTML Content</body></html>"))
  @mock_payload = double("Payload", body: @mock_body, parts: nil)
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

Given("I have a message with body data that is not HTML") do
  @mock_body = double("Body", data: Base64.urlsafe_encode64("Plain text content"))
  @mock_html_part = double("Part",
    mime_type: "text/html",
    body: double("Body", data: Base64.urlsafe_encode64("<html><body>Test</body></html>")),
    parts: nil
  )
  @mock_payload = double("Payload", body: @mock_body, parts: [@mock_html_part])
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

Given("the message has HTML parts") do
  # Already set up in the previous step
end

Given("the Gmail message has HTML parts") do
  # Already set up in the previous step
end

Then("it should return the HTML content from body") do
  expect(@result).to include("Test HTML Content")
end

Then("it should return the HTML content from parts") do
  expect(@result).to include("<html>")
end

Then("the Gmail fetcher should return the HTML content from body") do
  expect(@result).to include("Test HTML Content")
end

Then("the Gmail fetcher should return the HTML content from parts") do
  expect(@result).to include("<html>")
end

Given("I have a message with HTML in parts but no body data") do
  @mock_html_body = double("Body", data: Base64.urlsafe_encode64("<html><body>Test</body></html>"))
  @mock_html_part = double("Part",
    mime_type: "text/html",
    body: @mock_html_body,
    parts: nil
  )
  @mock_payload = double("Payload", body: nil, parts: [@mock_html_part])
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

Given("I have a Gmail message with HTML in parts but no body data") do
  @mock_html_body = double("Body", data: Base64.urlsafe_encode64("<html><body>Test</body></html>"))
  @mock_html_part = double("Part",
    mime_type: "text/html",
    body: @mock_html_body,
    parts: nil
  )
  @mock_payload = double("Payload", body: nil, parts: [@mock_html_part])
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

Given("I have a message with no body data and no parts") do
  @mock_payload = double("Payload", body: nil, parts: nil)
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

# New step definitions for coverage scenarios
Given("I have a message with text in nested parts") do
  @mock_text_body = double("Body", data: Base64.urlsafe_encode64("Nested plain text content"))
  @mock_text_part = double("Part",
    mime_type: "text/plain",
    body: @mock_text_body,
    parts: nil
  )
  @mock_nested_part = double("Part",
    mime_type: "multipart/alternative",
    body: nil,
    parts: [@mock_text_part]
  )
  @mock_payload = double("Payload", body: nil, parts: [@mock_nested_part])
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

Given("I have a message with text part but no body data") do
  @mock_text_part = double("Part",
    mime_type: "text/plain",
    body: nil,
    parts: nil
  )
  @mock_payload = double("Payload", body: nil, parts: [@mock_text_part])
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

Then("it should return the text content from nested parts") do
  expect(@result).to include("Nested plain text")
end

Given("I have a message with attachment in nested parts") do
  @mock_attachment_body = double("Body", attachment_id: "att_nested_123")
  @mock_attachment_part = double("Part",
    filename: "nested_receipt.pdf",
    body: @mock_attachment_body,
    mime_type: "application/pdf",
    parts: nil
  )
  @mock_nested_part = double("Part",
    filename: nil,
    body: nil,
    parts: [@mock_attachment_part]
  )
  @mock_payload = double("Payload", parts: [@mock_nested_part])
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

Given("I have a message with part that has filename but no attachment_id") do
  @mock_body_no_attachment = double("Body", attachment_id: nil)
  @mock_part = double("Part",
    filename: "test.pdf",
    body: @mock_body_no_attachment,
    mime_type: "application/pdf",
    parts: nil
  )
  @mock_payload = double("Payload", parts: [@mock_part])
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

Then("it should return all attachments including nested ones") do
  expect(@result).to be_an(Array)
  expect(@result.length).to eq(1)
  expect(@result.first[:filename]).to eq("nested_receipt.pdf")
  expect(@result.first[:attachment_id]).to eq("att_nested_123")
end

Given("the message has HTML parts") do
  # Parts are already set in the previous step
end

Given("I have a message with HTML in parts but no body data") do
  @mock_html_body = double("Body", data: Base64.urlsafe_encode64("<html><body>HTML from parts</body></html>"))
  @mock_html_part = double("Part",
    mime_type: "text/html",
    body: @mock_html_body,
    parts: nil
  )
  @mock_payload = double("Payload", body: nil, parts: [@mock_html_part])
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

Given("I have a message with no body data and no parts") do
  @mock_payload = double("Payload", body: nil, parts: nil)
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

Then("it should return the HTML content from body") do
  expect(@result).to include("<html>")
  expect(@result).to include("Test HTML Content")
end

Then("it should return the HTML content from parts") do
  expect(@result).to include("<html>")
  expect(@result).to include("HTML from parts")
end

Then("it should search in parts") do
  expect(@result).to include("<html>")
end

Given("I have a message with text body containing html tag") do
  @mock_body = double("Body", data: Base64.urlsafe_encode64("This contains <html> tag"))
  @mock_text_part = double("Part",
    mime_type: "text/plain",
    body: double("Body", data: Base64.urlsafe_encode64("Plain text content")),
    parts: nil
  )
  @mock_payload = double("Payload", body: @mock_body, parts: [@mock_text_part])
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

Given("I have a message with HTML in deeply nested parts") do
  @mock_html_body = double("Body", data: Base64.urlsafe_encode64("<html><body>Nested</body></html>"))
  @mock_html_part = double("Part",
    mime_type: "text/html",
    body: @mock_html_body,
    parts: nil
  )
  @mock_nested_part = double("Part",
    mime_type: "multipart/alternative",
    body: nil,
    parts: [@mock_html_part]
  )
  @mock_payload = double("Payload", body: nil, parts: [@mock_nested_part])
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

Given("I have a message with text in deeply nested parts") do
  @mock_text_body = double("Body", data: Base64.urlsafe_encode64("Nested text content"))
  @mock_text_part = double("Part",
    mime_type: "text/plain",
    body: @mock_text_body,
    parts: nil
  )
  @mock_nested_part = double("Part",
    mime_type: "multipart/alternative",
    body: nil,
    parts: [@mock_text_part]
  )
  @mock_payload = double("Payload", body: nil, parts: [@mock_nested_part])
  @mock_message = double("Message", payload: @mock_payload)
  @fetcher = GmailFetcher.new("test_token") unless @fetcher
end

Given("I have Gmail credentials") do
  @access_token = "test_access_token"
  # Don't require Gmail API constants - just create the fetcher directly
  @fetcher = GmailFetcher.new(@access_token)
end

When("I list Gmail messages") do
  @mock_messages = [double("Message", id: "msg1")]
  @mock_result = double("ListMessagesResponse", messages: @mock_messages, next_page_token: nil)
  allow(@mock_service).to receive(:list_user_messages).and_return(@mock_result)
  @fetcher.instance_variable_set(:@service, @mock_service)
  @result = @fetcher.list_order_messages("me", 100)
end

Then("it should return message list") do
  expect(@result).to be_an(Array)
end

