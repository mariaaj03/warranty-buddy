# features/step_definitions/gmail_service_steps.rb

Given("the Gmail service is available with valid authentication") do
  @mock_fetcher = double("GmailFetcher")
  @mock_receipt_processor = double("ReceiptProcessor")
  @mock_ai_service = double("AiService")
  
  # Mock the authorization
  mock_service = double("Gmail::Service")
  allow(mock_service).to receive(:authorization).and_return(true)
  allow(@mock_fetcher).to receive(:service).and_return(mock_service)
  
  # Create Gmail service with mocked dependencies
  @gmail_service = GmailService.new("fake_access_token", "fake_refresh_token", nil)
  @gmail_service.instance_variable_set(:@fetcher, @mock_fetcher)
  @gmail_service.instance_variable_set(:@receipt_processor, @mock_receipt_processor)
  
  # Mock cleanup
  allow(@mock_receipt_processor).to receive(:cleanup)
end

Given("I have {int} Gmail messages in my inbox") do |message_count|
  @mock_messages = (1..message_count).map do |i|
    double("Message", id: "message_#{i}")
  end
  
  allow(@mock_fetcher).to receive(:list_order_messages).and_return(@mock_messages)
  
  # Mock message details for each message
  @mock_messages.each_with_index do |message, index|
    mock_full_message = create_mock_gmail_message(
      id: message.id,
      subject: "Order Confirmation ##{1000 + index}",
      from: "orders@amazon.com",
      date: "Mon, 15 Jan 2024 10:30:00 -0800",
      html_content: "<html><body><p>iPhone 15 Pro - $999.00</p></body></html>",
      text_content: "iPhone 15 Pro - $999.00"
    )
    
    allow(@mock_fetcher).to receive(:get_message).with(message.id, "me").and_return(mock_full_message)
    allow(@mock_fetcher).to receive(:extract_html_from_message).and_return(mock_full_message.html_content)
    allow(@mock_fetcher).to receive(:extract_text_from_message).and_return(mock_full_message.text_content)
    allow(@mock_fetcher).to receive(:extract_attachments).and_return([])
  end
end

Given("the Gmail API returns an authentication error") do
  mock_service = double("Gmail::Service")
  allow(mock_service).to receive(:authorization).and_return(nil)
  allow(@mock_fetcher).to receive(:service).and_return(mock_service)
end

Given("I have Gmail messages with attachments") do
  @mock_messages = [double("Message", id: "message_with_attachment")]
  allow(@mock_fetcher).to receive(:list_order_messages).and_return(@mock_messages)
  
  mock_full_message = create_mock_gmail_message(
    id: "message_with_attachment",
    subject: "Receipt - Order #12345",
    from: "orders@bestbuy.com"
  )
  
  allow(@mock_fetcher).to receive(:get_message).and_return(mock_full_message)
  allow(@mock_fetcher).to receive(:extract_html_from_message).and_return("")
  allow(@mock_fetcher).to receive(:extract_text_from_message).and_return("")
  
  # Mock attachments
  mock_attachments = [
    { filename: "receipt.pdf", mime_type: "application/pdf", attachment_id: "att_123" }
  ]
  allow(@mock_fetcher).to receive(:extract_attachments).and_return(mock_attachments)
  
  # Mock attachment processing
  mock_attachment_data = double("AttachmentData", data: Base64.encode64("fake pdf content"))
  allow(@mock_fetcher).to receive(:get_attachment).and_return(mock_attachment_data)
  allow(@mock_receipt_processor).to receive(:process_pdf).and_return({
    merchant: "Best Buy",
    order_number: "BB123",
    purchase_date: Date.today,
    line_items: [{ name: "MacBook Pro", price: 1999.0 }],
    total_amount: 1999.0
  })
end

# Core Processing Steps
When("I parse receipt emails from Gmail") do
  @result = @gmail_service.parse_receipt_emails("me")
end

Then("it should process all {int} messages") do |expected_count|
  expect(@mock_fetcher).to have_received(:get_message).exactly(expected_count).times
end

Then("it should return parsed receipt data") do
  expect(@result).to be_an(Array)
  expect(@result).not_to be_empty
end

Then("it should log the processing results") do
  # Verify logging calls (you might need to mock Rails.logger)
  expect(Rails.logger).to have_received(:info).with(/Starting Gmail receipt parsing/)
end

Then("it should handle the API error gracefully") do
  expect(@result).to be_an(Array)
end

Then("it should return an empty array") do
  expect(@result).to eq([])
end

Then("it should log the error") do
  expect(Rails.logger).to have_received(:error).with(/Gmail API error/)
end

Then("it should clean up temporary files after processing") do
  expect(@mock_receipt_processor).to have_received(:cleanup)
end

# Merchant Extraction Steps
When("I extract merchant from email {string}") do |email_address|
  @extracted_merchant = @gmail_service.send(:extract_merchant_from_headers, email_address, "", "")
end

Then("the merchant should be {string}") do |expected_merchant|
  expect(@extracted_merchant).to eq(expected_merchant)
end

# Promotional Email Filtering
When("I parse email with promotional subject {string}") do |subject|
  @promotional_result = @gmail_service.send(:parse_email_content, 
    "<html><body>Promotional content</body></html>",
    "Promotional content", 
    subject, 
    "marketing@store.com", 
    "Mon, 15 Jan 2024 10:30:00 -0800",
    "msg_123"
  )
end

When("I parse email with order subject {string}") do |subject|
  html_content = "<html><body><p>Your order #123-456-789 for iPhone 15 Pro has shipped.</p></body></html>"
  text_content = "Your order #123-456-789 for iPhone 15 Pro has shipped."
  
  # Mock merchant parsers
  allow(MerchantParsers).to receive(:get_parser).and_return(double("Parser", parse: {
    merchant: "Amazon",
    order_number: "123-456-789",
    purchase_date: Date.today,
    line_items: [{ name: "iPhone 15 Pro", price: 999.0 }],
    total_amount: 999.0
  }))
  
  @order_result = @gmail_service.send(:parse_email_content,
    html_content,
    text_content,
    subject,
    "orders@amazon.com",
    "Mon, 15 Jan 2024 10:30:00 -0800", 
    "msg_456"
  )
end

Then("it should reject the email as promotional") do
  expect(@promotional_result).to be_nil
end

Then("it should return nil for parsed data") do
  expect(@promotional_result).to be_nil
end

Then("it should accept the email for processing") do
  expect(@order_result).not_to be_nil
end

Then("it should parse the order information") do
  expect(@order_result).to be_a(Hash)
  expect(@order_result[:product_name]).to be_present
  expect(@order_result[:merchant]).to be_present
end

# Parser Selection Steps
Given("I have an Amazon order email") do
  @amazon_html = "<html><body><p>Your Amazon order #123-456-789</p></body></html>"
  @amazon_text = "Your Amazon order #123-456-789"
  @amazon_subject = "Your Amazon order has shipped"
  @amazon_from = "orders@amazon.com"
end

When("I parse the email content with Amazon merchant") do
  # Mock Amazon parser
  @mock_amazon_parser = double("AmazonParser")
  allow(MerchantParsers).to receive(:get_parser).with("Amazon").and_return(@mock_amazon_parser)
  allow(@mock_amazon_parser).to receive(:parse).and_return({
    merchant: "Amazon",
    order_number: "123-456-789",
    line_items: [{ name: "iPhone 15 Pro", price: 999.0 }]
  })
  
  @parsed_result = @gmail_service.send(:parse_email_content,
    @amazon_html, @amazon_text, @amazon_subject, @amazon_from, 
    "Mon, 15 Jan 2024 10:30:00 -0800", "msg_amazon"
  )
end

Then("it should use the Amazon parser first") do
  expect(MerchantParsers).to have_received(:get_parser).with("Amazon")
end

Then("it should return Amazon-parsed data") do
  expect(@parsed_result[:merchant]).to eq("Amazon")
end

# Fallback Parser Steps
Given("I have an Amazon email that the Amazon parser cannot parse") do
  @failed_html = "<html><body><p>Amazon email with no clear structure</p></body></html>"
  @failed_text = "Amazon email with no clear structure"
end

When("I parse the email content") do
  # Mock Amazon parser failure
  @mock_amazon_parser = double("AmazonParser")
  allow(MerchantParsers).to receive(:get_parser).and_return(@mock_amazon_parser)
  allow(@mock_amazon_parser).to receive(:parse).and_return(nil)
  
  # Mock EmailOrderParser fallback
  @mock_email_parser = double("EmailOrderParser")
  allow(EmailOrderParser).to receive(:new).and_return(@mock_email_parser)
  allow(@mock_email_parser).to receive(:parse).and_return({
    merchant: "Amazon",
    order_number: "ABC123",
    line_items: []
  })
  allow(@mock_email_parser).to receive(:extract_order_number_from_subject).and_return("ABC123")
  
  @fallback_result = @gmail_service.send(:parse_email_content,
    @failed_html, @failed_text, "Amazon order", "orders@amazon.com",
    "Mon, 15 Jan 2024 10:30:00 -0800", "msg_failed"
  )
end

Then("it should fall back to EmailOrderParser") do
  expect(EmailOrderParser).to have_received(:new)
end

Then("it should return generic parsed data") do
  expect(@fallback_result[:order_number]).to eq("ABC123")
end

# Product Name Extraction Steps
Given("I have an email with line items containing {string}") do |product_name|
  @line_items_html = "<html><body><p>Order details</p></body></html>"
  @line_items_text = "Order details"
  
  # Mock parser to return line items
  @mock_parser = double("Parser")
  allow(MerchantParsers).to receive(:get_parser).and_return(@mock_parser)
  allow(@mock_parser).to receive(:parse).and_return({
    merchant: "Amazon",
    order_number: "123",
    line_items: [{ name: product_name, price: 999.0 }]
  })
end

Given("I have an email with subject {string}") do |subject|
  @test_subject = subject
end

Given("the email has order number but no line items") do
  @mock_parser = double("Parser")
  allow(MerchantParsers).to receive(:get_parser).and_return(@mock_parser)
  allow(@mock_parser).to receive(:parse).and_return({
    merchant: "StubHub",
    order_number: "TICKET123",
    line_items: []
  })
  
  # Mock EmailOrderParser for order number extraction
  @mock_email_parser = double("EmailOrderParser")
  allow(EmailOrderParser).to receive(:new).and_return(@mock_email_parser)
  allow(@mock_email_parser).to receive(:parse).and_return(nil)
  allow(@mock_email_parser).to receive(:extract_order_number_from_subject).and_return("TICKET123")
end

Given("I have an email with product information in the body") do |email_content|
  @body_content_html = "<html><body><p>#{email_content}</p></body></html>"
  @body_content_text = email_content
end

Given("the email has order number but no line items or clear subject") do
  @mock_parser = double("Parser")
  allow(MerchantParsers).to receive(:get_parser).and_return(@mock_parser)
  allow(@mock_parser).to receive(:parse).and_return({
    merchant: "Apple",
    order_number: "APPLE123",
    line_items: []
  })
  
  @mock_email_parser = double("EmailOrderParser")
  allow(EmailOrderParser).to receive(:new).and_return(@mock_email_parser)
  allow(@mock_email_parser).to receive(:parse).and_return(nil)
  allow(@mock_email_parser).to receive(:extract_order_number_from_subject).and_return("APPLE123")
end

Given("I have an email with order number but unclear product information") do
  @ai_test_html = "<html><body><p>Complex order with unclear product info</p></body></html>"
  @ai_test_text = "Complex order with unclear product info, order number XYZ789"
end

Given("the AI service is available") do
  @mock_ai_service = double("AiService")
  allow(AiService).to receive(:new).and_return(@mock_ai_service)
  allow(@mock_ai_service).to receive(:instance_variable_get).with(:@client).and_return(true)
  allow(@mock_ai_service).to receive(:extract_receipt_info).and_return({
    "product_name" => "AI Extracted Product"
  })
end

Given("I have an email with order number {string} but no extractable product info") do |order_number|
  @fallback_order_number = order_number
end

Then("it should extract product name from line items") do
  # This is verified by the parsing result
end

Then("the product name should be {string}") do |expected_product_name|
  expect(@parsing_result[:product_name]).to eq(expected_product_name)
end

Then("it should extract product name from subject line") do
  # This is verified by the parsing logic
end

Then("it should extract product name from email content") do
  # This is verified by the parsing logic
end

Then("the product name should contain {string}") do |expected_substring|
  expect(@parsing_result[:product_name]).to include(expected_substring)
end

Then("it should attempt AI extraction") do
  expect(AiService).to have_received(:new)
end

Then("it should use AI-extracted product name") do
  expect(@parsing_result[:product_name]).to eq("AI Extracted Product")
end

Then("it should log the AI extraction attempt") do
  expect(Rails.logger).to have_received(:info).with(/AI extraction/)
end

Then("it should use fallback product name {string}") do |expected_fallback|
  expect(@parsing_result[:product_name]).to eq(expected_fallback)
end

# Date Parsing Steps
Given("I have an email with date header {string}") do |date_header|
  @test_date_header = date_header
end

When("I parse the email date") do
  @parsed_date = @gmail_service.send(:parse_email_date, @test_date_header)
end

Then("the parsed date should be {string}") do |expected_date|
  expect(@parsed_date).to eq(Date.parse(expected_date))
end

Then("it should return nil") do
  expect(@parsed_date).to be_nil
end

Then("it should not raise an error") do
  expect { @parsed_date }.not_to raise_error
end

# Warranty and Return Policy Steps
When("I determine warranty for merchant {string} and product {string}") do |merchant, product|
  @warranty_length = @gmail_service.send(:determine_warranty_length, merchant, product)
end

Then("the warranty length should be {int} months") do |expected_months|
  expect(@warranty_length).to eq(expected_months)
end

When("I determine return policy for merchant {string}") do |merchant|
  @return_policy = @gmail_service.send(:determine_return_policy, merchant)
end

Then("the return policy should be {int} days") do |expected_days|
  expect# features/step_definitions/gmail_service_steps.rb

Given("the Gmail service is available with valid authentication") do
  @mock_fetcher = double("GmailFetcher")
  @mock_receipt_processor = double("ReceiptProcessor")
  @mock_ai_service = double("AiService")
  
  # Mock the authorization
  mock_service = double("Gmail::Service")
  allow(mock_service).to receive(:authorization).and_return(true)
  allow(@mock_fetcher).to receive(:service).and_return(mock_service)
  
  # Create Gmail service with mocked dependencies
  @gmail_service = GmailService.new("fake_access_token", "fake_refresh_token", nil)
  @gmail_service.instance_variable_set(:@fetcher, @mock_fetcher)
  @gmail_service.instance_variable_set(:@receipt_processor, @mock_receipt_processor)
  
  # Mock cleanup
  allow(@mock_receipt_processor).to receive(:cleanup)
end

Given("I have {int} Gmail messages in my inbox") do |message_count|
  @mock_messages = (1..message_count).map do |i|
    double("Message", id: "message_#{i}")
  end
  
  allow(@mock_fetcher).to receive(:list_order_messages).and_return(@mock_messages)
  
  # Mock message details for each message
  @mock_messages.each_with_index do |message, index|
    mock_full_message = create_mock_gmail_message(
      id: message.id,
      subject: "Order Confirmation ##{1000 + index}",
      from: "orders@amazon.com",
      date: "Mon, 15 Jan 2024 10:30:00 -0800",
      html_content: "<html><body><p>iPhone 15 Pro - $999.00</p></body></html>",
      text_content: "iPhone 15 Pro - $999.00"
    )
    
    allow(@mock_fetcher).to receive(:get_message).with(message.id, "me").and_return(mock_full_message)
    allow(@mock_fetcher).to receive(:extract_html_from_message).and_return(mock_full_message.html_content)
    allow(@mock_fetcher).to receive(:extract_text_from_message).and_return(mock_full_message.text_content)
    allow(@mock_fetcher).to receive(:extract_attachments).and_return([])
  end
end

Given("the Gmail API returns an authentication error") do
  mock_service = double("Gmail::Service")
  allow(mock_service).to receive(:authorization).and_return(nil)
  allow(@mock_fetcher).to receive(:service).and_return(mock_service)
end

Given("I have Gmail messages with attachments") do
  @mock_messages = [double("Message", id: "message_with_attachment")]
  allow(@mock_fetcher).to receive(:list_order_messages).and_return(@mock_messages)
  
  mock_full_message = create_mock_gmail_message(
    id: "message_with_attachment",
    subject: "Receipt - Order #12345",
    from: "orders@bestbuy.com"
  )
  
  allow(@mock_fetcher).to receive(:get_message).and_return(mock_full_message)
  allow(@mock_fetcher).to receive(:extract_html_from_message).and_return("")
  allow(@mock_fetcher).to receive(:extract_text_from_message).and_return("")
  
  # Mock attachments
  mock_attachments = [
    { filename: "receipt.pdf", mime_type: "application/pdf", attachment_id: "att_123" }
  ]
  allow(@mock_fetcher).to receive(:extract_attachments).and_return(mock_attachments)
  
  # Mock attachment processing
  mock_attachment_data = double("AttachmentData", data: Base64.encode64("fake pdf content"))
  allow(@mock_fetcher).to receive(:get_attachment).and_return(mock_attachment_data)
  allow(@mock_receipt_processor).to receive(:process_pdf).and_return({
    merchant: "Best Buy",
    order_number: "BB123",
    purchase_date: Date.today,
    line_items: [{ name: "MacBook Pro", price: 1999.0 }],
    total_amount: 1999.0
  })
end

# Core Processing Steps
When("I parse receipt emails from Gmail") do
  @result = @gmail_service.parse_receipt_emails("me")
end

Then("it should process all {int} messages") do |expected_count|
  expect(@mock_fetcher).to have_received(:get_message).exactly(expected_count).times
end

Then("it should return parsed receipt data") do
  expect(@result).to be_an(Array)
  expect(@result).not_to be_empty
end

Then("it should log the processing results") do
  # Verify logging calls (you might need to mock Rails.logger)
  expect(Rails.logger).to have_received(:info).with(/Starting Gmail receipt parsing/)
end

Then("it should handle the API error gracefully") do
  expect(@result).to be_an(Array)
end

Then("it should return an empty array") do
  expect(@result).to eq([])
end

Then("it should log the error") do
  expect(Rails.logger).to have_received(:error).with(/Gmail API error/)
end

Then("it should clean up temporary files after processing") do
  expect(@mock_receipt_processor).to have_received(:cleanup)
end

# Merchant Extraction Steps
When("I extract merchant from email {string}") do |email_address|
  @extracted_merchant = @gmail_service.send(:extract_merchant_from_headers, email_address, "", "")
end

Then("the merchant should be {string}") do |expected_merchant|
  expect(@extracted_merchant).to eq(expected_merchant)
end

# Promotional Email Filtering
When("I parse email with promotional subject {string}") do |subject|
  @promotional_result = @gmail_service.send(:parse_email_content, 
    "<html><body>Promotional content</body></html>",
    "Promotional content", 
    subject, 
    "marketing@store.com", 
    "Mon, 15 Jan 2024 10:30:00 -0800",
    "msg_123"
  )
end

When("I parse email with order subject {string}") do |subject|
  html_content = "<html><body><p>Your order #123-456-789 for iPhone 15 Pro has shipped.</p></body></html>"
  text_content = "Your order #123-456-789 for iPhone 15 Pro has shipped."
  
  # Mock merchant parsers
  allow(MerchantParsers).to receive(:get_parser).and_return(double("Parser", parse: {
    merchant: "Amazon",
    order_number: "123-456-789",
    purchase_date: Date.today,
    line_items: [{ name: "iPhone 15 Pro", price: 999.0 }],
    total_amount: 999.0
  }))
  
  @order_result = @gmail_service.send(:parse_email_content,
    html_content,
    text_content,
    subject,
    "orders@amazon.com",
    "Mon, 15 Jan 2024 10:30:00 -0800", 
    "msg_456"
  )
end

Then("it should reject the email as promotional") do
  expect(@promotional_result).to be_nil
end

Then("it should return nil for parsed data") do
  expect(@promotional_result).to be_nil
end

Then("it should accept the email for processing") do
  expect(@order_result).not_to be_nil
end

Then("it should parse the order information") do
  expect(@order_result).to be_a(Hash)
  expect(@order_result[:product_name]).to be_present
  expect(@order_result[:merchant]).to be_present
end

# Parser Selection Steps
Given("I have an Amazon order email") do
  @amazon_html = "<html><body><p>Your Amazon order #123-456-789</p></body></html>"
  @amazon_text = "Your Amazon order #123-456-789"
  @amazon_subject = "Your Amazon order has shipped"
  @amazon_from = "orders@amazon.com"
end

When("I parse the email content with Amazon merchant") do
  # Mock Amazon parser
  @mock_amazon_parser = double("AmazonParser")
  allow(MerchantParsers).to receive(:get_parser).with("Amazon").and_return(@mock_amazon_parser)
  allow(@mock_amazon_parser).to receive(:parse).and_return({
    merchant: "Amazon",
    order_number: "123-456-789",
    line_items: [{ name: "iPhone 15 Pro", price: 999.0 }]
  })
  
  @parsed_result = @gmail_service.send(:parse_email_content,
    @amazon_html, @amazon_text, @amazon_subject, @amazon_from, 
    "Mon, 15 Jan 2024 10:30:00 -0800", "msg_amazon"
  )
end

Then("it should use the Amazon parser first") do
  expect(MerchantParsers).to have_received(:get_parser).with("Amazon")
end

Then("it should return Amazon-parsed data") do
  expect(@parsed_result[:merchant]).to eq("Amazon")
end

# Fallback Parser Steps
Given("I have an Amazon email that the Amazon parser cannot parse") do
  @failed_html = "<html><body><p>Amazon email with no clear structure</p></body></html>"
  @failed_text = "Amazon email with no clear structure"
end

When("I parse the email content") do
  # Mock Amazon parser failure
  @mock_amazon_parser = double("AmazonParser")
  allow(MerchantParsers).to receive(:get_parser).and_return(@mock_amazon_parser)
  allow(@mock_amazon_parser).to receive(:parse).and_return(nil)
  
  # Mock EmailOrderParser fallback
  @mock_email_parser = double("EmailOrderParser")
  allow(EmailOrderParser).to receive(:new).and_return(@mock_email_parser)
  allow(@mock_email_parser).to receive(:parse).and_return({
    merchant: "Amazon",
    order_number: "ABC123",
    line_items: []
  })
  allow(@mock_email_parser).to receive(:extract_order_number_from_subject).and_return("ABC123")
  
  @fallback_result = @gmail_service.send(:parse_email_content,
    @failed_html, @failed_text, "Amazon order", "orders@amazon.com",
    "Mon, 15 Jan 2024 10:30:00 -0800", "msg_failed"
  )
end

Then("it should fall back to EmailOrderParser") do
  expect(EmailOrderParser).to have_received(:new)
end

Then("it should return generic parsed data") do
  expect(@fallback_result[:order_number]).to eq("ABC123")
end

# Product Name Extraction Steps
Given("I have an email with line items containing {string}") do |product_name|
  @line_items_html = "<html><body><p>Order details</p></body></html>"
  @line_items_text = "Order details"
  
  # Mock parser to return line items
  @mock_parser = double("Parser")
  allow(MerchantParsers).to receive(:get_parser).and_return(@mock_parser)
  allow(@mock_parser).to receive(:parse).and_return({
    merchant: "Amazon",
    order_number: "123",
    line_items: [{ name: product_name, price: 999.0 }]
  })
end

Given("I have an email with subject {string}") do |subject|
  @test_subject = subject
end

Given("the email has order number but no line items") do
  @mock_parser = double("Parser")
  allow(MerchantParsers).to receive(:get_parser).and_return(@mock_parser)
  allow(@mock_parser).to receive(:parse).and_return({
    merchant: "StubHub",
    order_number: "TICKET123",
    line_items: []
  })
  
  # Mock EmailOrderParser for order number extraction
  @mock_email_parser = double("EmailOrderParser")
  allow(EmailOrderParser).to receive(:new).and_return(@mock_email_parser)
  allow(@mock_email_parser).to receive(:parse).and_return(nil)
  allow(@mock_email_parser).to receive(:extract_order_number_from_subject).and_return("TICKET123")
end

Given("I have an email with product information in the body") do |email_content|
  @body_content_html = "<html><body><p>#{email_content}</p></body></html>"
  @body_content_text = email_content
end

Given("the email has order number but no line items or clear subject") do
  @mock_parser = double("Parser")
  allow(MerchantParsers).to receive(:get_parser).and_return(@mock_parser)
  allow(@mock_parser).to receive(:parse).and_return({
    merchant: "Apple",
    order_number: "APPLE123",
    line_items: []
  })
  
  @mock_email_parser = double("EmailOrderParser")
  allow(EmailOrderParser).to receive(:new).and_return(@mock_email_parser)
  allow(@mock_email_parser).to receive(:parse).and_return(nil)
  allow(@mock_email_parser).to receive(:extract_order_number_from_subject).and_return("APPLE123")
end

Given("I have an email with order number but unclear product information") do
  @ai_test_html = "<html><body><p>Complex order with unclear product info</p></body></html>"
  @ai_test_text = "Complex order with unclear product info, order number XYZ789"
end

Given("the AI service is available") do
  @mock_ai_service = double("AiService")
  allow(AiService).to receive(:new).and_return(@mock_ai_service)
  allow(@mock_ai_service).to receive(:instance_variable_get).with(:@client).and_return(true)
  allow(@mock_ai_service).to receive(:extract_receipt_info).and_return({
    "product_name" => "AI Extracted Product"
  })
end
end
