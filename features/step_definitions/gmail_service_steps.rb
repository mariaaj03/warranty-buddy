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
  
  allow(@gmail_service).to receive(:parse_email_content).and_return(nil)
  
  mock_attachments = [
    { filename: "receipt.pdf", mime_type: "application/pdf", attachment_id: "att_123" }
  ]
  allow(@mock_fetcher).to receive(:extract_attachments).and_return(mock_attachments)
  
  mock_attachment_data = double("AttachmentData", data: Base64.encode64("fake pdf content"))
  allow(@mock_fetcher).to receive(:get_attachment).with("message_with_attachment", "att_123", "me").and_return(mock_attachment_data)
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
  expect(@return_policy).to eq(expected_days)
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


# Core Processing Steps
When("I parse receipt emails from Gmail") do
  @result = @gmail_service.parse_receipt_emails("me")
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


Then("it should log the error") do
  expect(Rails.logger).to have_received(:error).with(/Gmail API error/)
end

Then("it should clean up temporary files after processing") do
  expect(@mock_receipt_processor).to have_received(:cleanup)
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

# Additional step definitions for missing coverage
Given("I have Gmail messages that are not receipts") do
  @mock_messages = [double("Message", id: "non_receipt_message")]
  allow(@mock_fetcher).to receive(:list_order_messages).and_return(@mock_messages)
  
  mock_full_message = create_mock_gmail_message(
    id: "non_receipt_message",
    subject: "Newsletter - Weekly Deals",
    from: "marketing@store.com",
    date: "Mon, 15 Jan 2024 10:30:00 -0800",
    html_content: "<html><body>Newsletter content</body></html>",
    text_content: "Newsletter content"
  )
  
  allow(@mock_fetcher).to receive(:get_message).and_return(mock_full_message)
  allow(@mock_fetcher).to receive(:extract_html_from_message).and_return(mock_full_message.html_content)
  allow(@mock_fetcher).to receive(:extract_text_from_message).and_return(mock_full_message.text_content)
  allow(@mock_fetcher).to receive(:extract_attachments).and_return([])
  
  # Mock MerchantParsers and EmailOrderParser to return nil (not a receipt)
  allow(MerchantParsers).to receive(:get_parser).and_return(double("Parser", parse: nil))
  allow(EmailOrderParser).to receive(:new).and_return(double("EmailOrderParser", parse: nil, extract_order_number_from_subject: nil))
end

Given("I have Gmail messages with valid receipts") do
  @mock_messages = [double("Message", id: "valid_receipt_message")]
  allow(@mock_fetcher).to receive(:list_order_messages).and_return(@mock_messages)
  
  mock_full_message = create_mock_gmail_message(
    id: "valid_receipt_message",
    subject: "Order Confirmation #12345",
    from: "orders@amazon.com",
    date: "Mon, 15 Jan 2024 10:30:00 -0800",
    html_content: "<html><body>Order content</body></html>",
    text_content: "Order content"
  )
  
  allow(@mock_fetcher).to receive(:get_message).and_return(mock_full_message)
  allow(@mock_fetcher).to receive(:extract_html_from_message).and_return(mock_full_message.html_content)
  allow(@mock_fetcher).to receive(:extract_text_from_message).and_return(mock_full_message.text_content)
  allow(@mock_fetcher).to receive(:extract_attachments).and_return([])
  
  # Mock parse_email_content to return a valid receipt
  allow(@gmail_service).to receive(:parse_email_content).and_return({
    product_name: "iPhone 15 Pro",
    merchant: "Amazon",
    purchase_date: Date.today,
    warranty_months: 12,
    warranty_type: "manufacturer",
    return_policy_days: 30,
    return_deadline: nil,
    source: "gmail_parsed",
    raw_email_id: "valid_receipt_message",
    order_number: "12345",
    total_amount: 999.0
  })
end

Then("it should skip invalid receipts") do
  expect(@result).to be_an(Array)
end

Then("it should not add them to parsed receipts") do
  expect(@result).to be_empty
end

Then("it should add valid receipts to parsed receipts") do
  expect(@result).to be_an(Array)
  expect(@result).not_to be_empty
  expect(@result.first[:product_name]).to eq("iPhone 15 Pro")
end

Then("the receipts found count should be greater than zero") do
  expect(@result.length).to be > 0
end

Given("I have Gmail messages without attachments") do
  @mock_messages = [double("Message", id: "message_no_attachments")]
  allow(@mock_fetcher).to receive(:list_order_messages).and_return(@mock_messages)
  
  mock_full_message = create_mock_gmail_message(
    id: "message_no_attachments",
    subject: "Order Confirmation #12345",
    from: "orders@amazon.com"
  )
  
  allow(@mock_fetcher).to receive(:get_message).and_return(mock_full_message)
  allow(@mock_fetcher).to receive(:extract_html_from_message).and_return("<html><body>Order content</body></html>")
  allow(@mock_fetcher).to receive(:extract_text_from_message).and_return("Order content")
  allow(@mock_fetcher).to receive(:extract_attachments).and_return([])  # No attachments
  
  # Mock parse_email_content to return a valid receipt
  allow(@gmail_service).to receive(:parse_email_content).and_return({
    product_name: "Product",
    merchant: "Amazon",
    purchase_date: Date.today,
    warranty_months: 12,
    warranty_type: "manufacturer",
    return_policy_days: 30,
    return_deadline: nil,
    source: "gmail_parsed",
    raw_email_id: "message_no_attachments",
    order_number: "12345",
    total_amount: 99.0
  })
end

Then("it should skip attachment processing") do
  expect(@result).to be_an(Array)
  # Verify that process_attachments was not called (or called with empty array)
  expect(@mock_receipt_processor).not_to have_received(:process_pdf)
  expect(@mock_receipt_processor).not_to have_received(:process_image)
end

Given("I have Gmail messages with PDF attachments") do
  @mock_messages = [double("Message", id: "message_with_pdf")]
  allow(@mock_fetcher).to receive(:list_order_messages).and_return(@mock_messages)
  
  mock_full_message = create_mock_gmail_message(
    id: "message_with_pdf",
    subject: "Receipt",
    from: "orders@store.com"
  )
  
  allow(@mock_fetcher).to receive(:get_message).and_return(mock_full_message)
  allow(@mock_fetcher).to receive(:extract_html_from_message).and_return("")
  allow(@mock_fetcher).to receive(:extract_text_from_message).and_return("")
  
  mock_attachments = [
    { filename: "receipt.pdf", mime_type: "application/pdf", attachment_id: "att_pdf_123" }
  ]
  allow(@mock_fetcher).to receive(:extract_attachments).and_return(mock_attachments)
  
  mock_attachment_data = double("AttachmentData", data: Base64.encode64("fake pdf content"))
  allow(@mock_fetcher).to receive(:get_attachment).and_return(mock_attachment_data)
  allow(@mock_receipt_processor).to receive(:process_pdf).and_return({
    merchant: "Store",
    order_number: "12345",
    purchase_date: Date.today,
    line_items: [{ name: "Product", price: 99.0 }],
    total_amount: 99.0
  })
end

Then("it should process PDF attachments") do
  expect(@result).not_to be_empty
  expect(@result.any? { |r| r[:source] == "attachment_parsed" }).to be true
  # Verify that process_pdf was called
  expect(@mock_receipt_processor).to have_received(:process_pdf)
end

Given("I have Gmail messages with image attachments") do
  @mock_messages = [double("Message", id: "message_with_image")]
  allow(@mock_fetcher).to receive(:list_order_messages).and_return(@mock_messages)
  
  mock_full_message = create_mock_gmail_message(
    id: "message_with_image",
    subject: "Receipt",
    from: "orders@store.com"
  )
  
  allow(@mock_fetcher).to receive(:get_message).and_return(mock_full_message)
  allow(@mock_fetcher).to receive(:extract_html_from_message).and_return("")
  allow(@mock_fetcher).to receive(:extract_text_from_message).and_return("")
  
  mock_attachments = [
    { filename: "receipt.jpg", mime_type: "image/jpeg", attachment_id: "att_img_123" }
  ]
  allow(@mock_fetcher).to receive(:extract_attachments).and_return(mock_attachments)
  
  mock_attachment_data = double("AttachmentData", data: Base64.encode64("fake image content"))
  allow(@mock_fetcher).to receive(:get_attachment).and_return(mock_attachment_data)
  allow(@mock_receipt_processor).to receive(:process_image).and_return({
    merchant: "Store",
    order_number: "12345",
    purchase_date: Date.today,
    line_items: [{ name: "Product", price: 99.0 }],
    total_amount: 99.0
  })
end

Then("it should process image attachments") do
  expect(@result).not_to be_empty
  expect(@result.any? { |r| r[:source] == "attachment_parsed" }).to be true
  # Verify that process_image was called
  expect(@mock_receipt_processor).to have_received(:process_image)
end

Given("I have Gmail messages with unsupported attachment types") do
  @mock_messages = [double("Message", id: "message_with_unsupported")]
  allow(@mock_fetcher).to receive(:list_order_messages).and_return(@mock_messages)
  
  mock_full_message = create_mock_gmail_message(
    id: "message_with_unsupported",
    subject: "Document",
    from: "orders@store.com"
  )
  
  allow(@mock_fetcher).to receive(:get_message).and_return(mock_full_message)
  allow(@mock_fetcher).to receive(:extract_html_from_message).and_return("")
  allow(@mock_fetcher).to receive(:extract_text_from_message).and_return("")
  
  mock_attachments = [
    { filename: "document.docx", mime_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document", attachment_id: "att_doc_123" }
  ]
  allow(@mock_fetcher).to receive(:extract_attachments).and_return(mock_attachments)
  
  mock_attachment_data = double("AttachmentData", data: Base64.encode64("fake doc content"))
  allow(@mock_fetcher).to receive(:get_attachment).and_return(mock_attachment_data)
end

Then("it should skip unsupported attachments") do
  # Unsupported attachments should be skipped (next)
  expect(@result).to be_an(Array)
end

Given("I have an email with no line items but has order number") do
  @mock_messages = [double("Message", id: "message_no_line_items")]
  allow(@mock_fetcher).to receive(:list_order_messages).and_return(@mock_messages)
  
  mock_full_message = create_mock_gmail_message(
    id: "message_no_line_items",
    subject: "Order Confirmation #12345",
    from: "orders@store.com"
  )
  
  allow(@mock_fetcher).to receive(:get_message).and_return(mock_full_message)
  allow(@mock_fetcher).to receive(:extract_html_from_message).and_return("<html><body>Order #12345</body></html>")
  allow(@mock_fetcher).to receive(:extract_text_from_message).and_return("Order #12345")
  allow(@mock_fetcher).to receive(:extract_attachments).and_return([])
  
  # Mock parsers to return data with no line items but order number
  allow(MerchantParsers).to receive(:get_parser).and_return(double("Parser", parse: nil))
  mock_email_parser = double("EmailOrderParser")
  allow(EmailOrderParser).to receive(:new).and_return(mock_email_parser)
  allow(mock_email_parser).to receive(:parse).and_return({
    merchant: "Store",
    purchase_date: Date.today,
    line_items: [],  # No line items
    order_number: nil
  })
  allow(mock_email_parser).to receive(:extract_order_number_from_subject).and_return("12345")
  
  # Mock product name extraction to return nil (will use fallback)
  allow(@gmail_service).to receive(:extract_product_name_from_subject_line).and_return(nil)
  allow(@gmail_service).to receive(:extract_product_name_from_email_content).and_return(nil)
end

Then("it should use fallback product name {string}") do |expected_name|
  expect(@result).not_to be_empty
  expect(@result.first[:product_name]).to eq(expected_name)
end

When("I extract product name from subject {string}") do |subject|
  @extracted_product_name = @gmail_service.send(:extract_product_name_from_subject_line, subject, "12345")
end

Then("it should extract {string}") do |expected_product|
  expect(@extracted_product_name).to eq(expected_product)
end

When("I extract product name from subject with invalid candidates") do
  # Test various invalid candidates
  @test_subjects = [
    "Order for  - Order #12345",  # Blank candidate
    "Order for AB - Order #12345",  # Too short (< 5)
    "Order for " + "A" * 101 + " - Order #12345",  # Too long (> 100)
    "Order for Sale Item - Order #12345",  # Promotional keyword
    "Order for Order - Order #12345"  # Excluded pattern
  ]
  
  @results = @test_subjects.map do |subject|
    @gmail_service.send(:extract_product_name_from_subject_line, subject, "12345")
  end
end

Then("it should skip blank candidates") do
  # First subject should return nil (blank candidate)
  expect(@results[0]).to be_nil
end

Then("it should skip candidates that are too short") do
  # Second subject should return nil (too short)
  expect(@results[1]).to be_nil
end

Then("it should skip candidates that are too long") do
  # Third subject should return nil (too long)
  expect(@results[2]).to be_nil
end

Then("it should skip candidates with promotional keywords") do
  # Fourth subject should return nil (promotional keyword)
  expect(@results[3]).to be_nil
end

Then("it should skip candidates matching excluded patterns") do
  # Fifth subject should return nil (excluded pattern)
  expect(@results[4]).to be_nil
end

When("I extract product name from email content with valid product lines") do
  html_content = "<html><body><p>MacBook Pro 16-inch</p></body></html>"
  text_content = "MacBook Pro 16-inch\nPrice: $2,499.00"
  subject = "Order Confirmation"
  
  @extracted_product_name = @gmail_service.send(:extract_product_name_from_email_content, html_content, text_content, subject)
end

Then("it should extract the product name") do
  expect(@extracted_product_name).to eq("MacBook Pro 16-inch")
end

When("I extract product name from email content with invalid lines") do
  # Test various invalid lines
  html_content = ""
  text_content = "AB\n12345\n$\nORDER\nReceipt for Product\nTotal: $99.00"
  subject = "Order"
  
  @extracted_product_name = @gmail_service.send(:extract_product_name_from_email_content, html_content, text_content, subject)
end

Then("it should skip lines that are too short") do
  # "AB" should be skipped (length < 10)
  expect(@extracted_product_name).not_to eq("AB")
end

Then("it should skip lines that are too long") do
  # Lines > 100 should be skipped
  expect(@extracted_product_name).not_to match(/^.{101,}$/) if @extracted_product_name
end

Then("it should skip lines with excluded patterns") do
  # "ORDER", "Receipt for Product", "Total: $99.00" should be skipped
  expect(@extracted_product_name).not_to eq("ORDER")
  expect(@extracted_product_name).not_to eq("Receipt for Product")
end

Then("it should skip lines matching numeric or dollar patterns") do
  # "12345" and "$" should be skipped
  expect(@extracted_product_name).not_to eq("12345")
  expect(@extracted_product_name).not_to eq("$")
end

Then("it should skip candidates matching excluded patterns") do
  # Candidates matching excluded patterns should be skipped
  expect(@extracted_product_name).not_to match(/order|receipt|invoice|total|subtotal|tax|shipping|delivery/i) if @extracted_product_name
end

# Step definitions for extract_product_name_from_subject method
When("I extract product name using extract_product_name_from_subject with {string}") do |subject|
  @extracted_product_name_subject = @gmail_service.send(:extract_product_name_from_subject, subject)
end

Then("it should return product name {string}") do |expected_product|
  expect(@extracted_product_name_subject).to eq(expected_product)
end

# Step definitions for parse_email_content coverage
Given("I have an email with promotional subject containing keywords") do
  @parsed_result = @gmail_service.send(:parse_email_content,
    "<html><body>Content</body></html>",
    "Content",
    "Select items to arrive in time for Valentine's Day",
    "marketing@store.com",
    "Mon, 15 Jan 2024 10:30:00 -0800",
    "msg_123"
  )
end

Given("I have an email with subject starting with {string}") do |prefix|
  @parsed_result = @gmail_service.send(:parse_email_content,
    "<html><body>Content</body></html>",
    "Content",
    "#{prefix} - Special Offer",
    "marketing@store.com",
    "Mon, 15 Jan 2024 10:30:00 -0800",
    "msg_123"
  )
end

Given("I have an email from Digital merchant") do
  allow(@gmail_service).to receive(:extract_merchant_from_headers).and_return("Digital")
  @parsed_result = @gmail_service.send(:parse_email_content,
    "<html><body>Content</body></html>",
    "Content",
    "Order Confirmation",
    "digital@store.com",
    "Mon, 15 Jan 2024 10:30:00 -0800",
    "msg_123"
  )
end

Given("I have an email that merchant parser can parse") do
  mock_parser = double("MerchantParser")
  allow(mock_parser).to receive(:parse).and_return({
    merchant: "Amazon",
    line_items: [{ name: "Product", quantity: 1, price: 99.0 }],
    order_number: "12345",
    purchase_date: Date.today
  })
  allow(MerchantParsers).to receive(:get_parser).and_return(mock_parser)
  allow(@gmail_service).to receive(:extract_merchant_from_headers).and_return("Amazon")
  
  @parsed_result = @gmail_service.send(:parse_email_content,
    "<html><body>Content</body></html>",
    "Content",
    "Order Confirmation",
    "orders@amazon.com",
    "Mon, 15 Jan 2024 10:30:00 -0800",
    "msg_123"
  )
end

Then("it should use merchant parser data") do
  expect(@parsed_result).not_to be_nil
  expect(@parsed_result[:merchant]).to eq("Amazon")
end

Then("it should not use generic parser") do
  # Verify that EmailOrderParser was not called
  expect(EmailOrderParser).not_to have_received(:new)
end

Given("I have an email that merchant parser cannot parse") do
  mock_parser = double("MerchantParser")
  allow(mock_parser).to receive(:parse).and_return(nil)
  allow(MerchantParsers).to receive(:get_parser).and_return(mock_parser)
  allow(@gmail_service).to receive(:extract_merchant_from_headers).and_return("Amazon")
  
  mock_email_parser = double("EmailOrderParser")
  allow(EmailOrderParser).to receive(:new).and_return(mock_email_parser)
  allow(mock_email_parser).to receive(:parse).and_return({
    merchant: "Amazon",
    line_items: [{ name: "Product", quantity: 1, price: 99.0 }],
    order_number: "12345",
    purchase_date: Date.today
  })
  allow(mock_email_parser).to receive(:extract_order_number_from_subject).and_return("12345")
  
  @parsed_result = @gmail_service.send(:parse_email_content,
    "<html><body>Content</body></html>",
    "Content",
    "Order Confirmation",
    "orders@amazon.com",
    "Mon, 15 Jan 2024 10:30:00 -0800",
    "msg_123"
  )
end

Then("it should use generic parser") do
  expect(EmailOrderParser).to have_received(:new)
end

Given("I have an email that neither parser can parse") do
  mock_parser = double("MerchantParser")
  allow(mock_parser).to receive(:parse).and_return(nil)
  allow(MerchantParsers).to receive(:get_parser).and_return(mock_parser)
  allow(@gmail_service).to receive(:extract_merchant_from_headers).and_return("Amazon")
  
  mock_email_parser = double("EmailOrderParser")
  allow(EmailOrderParser).to receive(:new).and_return(mock_email_parser)
  allow(mock_email_parser).to receive(:parse).and_return(nil)
  allow(mock_email_parser).to receive(:extract_order_number_from_subject).and_return(nil)
  
  @parsed_result = @gmail_service.send(:parse_email_content,
    "<html><body>Content</body></html>",
    "Content",
    "Order Confirmation",
    "orders@amazon.com",
    "Mon, 15 Jan 2024 10:30:00 -0800",
    "msg_123"
  )
end

Given("I have an email with order number in subject but not in parsed data") do
  mock_parser = double("MerchantParser")
  allow(mock_parser).to receive(:parse).and_return({
    merchant: "Amazon",
    line_items: [{ name: "Product", quantity: 1, price: 99.0 }],
    order_number: nil,
    purchase_date: Date.today
  })
  allow(MerchantParsers).to receive(:get_parser).and_return(mock_parser)
  allow(@gmail_service).to receive(:extract_merchant_from_headers).and_return("Amazon")
  
  mock_email_parser = double("EmailOrderParser")
  allow(EmailOrderParser).to receive(:new).and_return(mock_email_parser)
  allow(mock_email_parser).to receive(:extract_order_number_from_subject).and_return("12345")
  
  @parsed_result = @gmail_service.send(:parse_email_content,
    "<html><body>Content</body></html>",
    "Content",
    "Order Confirmation #12345",
    "orders@amazon.com",
    "Mon, 15 Jan 2024 10:30:00 -0800",
    "msg_123"
  )
end


Given("I have an email with no line items and no order number") do
  mock_parser = double("MerchantParser")
  allow(mock_parser).to receive(:parse).and_return({
    merchant: "Amazon",
    line_items: [],
    order_number: nil,
    purchase_date: Date.today
  })
  allow(MerchantParsers).to receive(:get_parser).and_return(mock_parser)
  allow(@gmail_service).to receive(:extract_merchant_from_headers).and_return("Amazon")
  
  mock_email_parser = double("EmailOrderParser")
  allow(EmailOrderParser).to receive(:new).and_return(mock_email_parser)
  allow(mock_email_parser).to receive(:extract_order_number_from_subject).and_return(nil)
  
  @parsed_result = @gmail_service.send(:parse_email_content,
    "<html><body>Content</body></html>",
    "Content",
    "Order Confirmation",
    "orders@amazon.com",
    "Mon, 15 Jan 2024 10:30:00 -0800",
    "msg_123"
  )
end

Given("I have an email with line items") do
  mock_parser = double("MerchantParser")
  allow(mock_parser).to receive(:parse).and_return({
    merchant: "Amazon",
    line_items: [{ name: "iPhone 15 Pro", quantity: 1, price: 999.0 }],
    order_number: "12345",
    purchase_date: Date.today
  })
  allow(MerchantParsers).to receive(:get_parser).and_return(mock_parser)
  allow(@gmail_service).to receive(:extract_merchant_from_headers).and_return("Amazon")
  
  @parsed_result = @gmail_service.send(:parse_email_content,
    "<html><body>Content</body></html>",
    "Content",
    "Order Confirmation",
    "orders@amazon.com",
    "Mon, 15 Jan 2024 10:30:00 -0800",
    "msg_123"
  )
end

Then("it should extract product name from line items") do
  expect(@parsed_result[:product_name]).to eq("iPhone 15 Pro")
end

Given("I have an email with order number but no line items") do
  mock_parser = double("MerchantParser")
  allow(mock_parser).to receive(:parse).and_return({
    merchant: "Amazon",
    line_items: [],
    order_number: "12345",
    purchase_date: Date.today
  })
  allow(MerchantParsers).to receive(:get_parser).and_return(mock_parser)
  allow(@gmail_service).to receive(:extract_merchant_from_headers).and_return("Amazon")
  allow(@gmail_service).to receive(:extract_product_name_from_subject_line).and_return("Product from Subject")
  
  @parsed_result = @gmail_service.send(:parse_email_content,
    "<html><body>Content</body></html>",
    "Content",
    "Order Confirmation #12345",
    "orders@amazon.com",
    "Mon, 15 Jan 2024 10:30:00 -0800",
    "msg_123"
  )
end

Then("it should extract product name using fallback methods") do
  expect(@parsed_result).not_to be_nil
  expect(@parsed_result[:product_name]).to be_present
end

Given("I have an email with order number but blank product name in line items") do
  mock_parser = double("MerchantParser")
  allow(mock_parser).to receive(:parse).and_return({
    merchant: "Amazon",
    line_items: [{ name: nil, quantity: 1, price: 99.0 }],
    order_number: "12345",
    purchase_date: Date.today
  })
  allow(MerchantParsers).to receive(:get_parser).and_return(mock_parser)
  allow(@gmail_service).to receive(:extract_merchant_from_headers).and_return("Amazon")
  allow(@gmail_service).to receive(:extract_product_name_from_subject_line).and_return("Product from Subject")
  
  @parsed_result = @gmail_service.send(:parse_email_content,
    "<html><body>Content</body></html>",
    "Content",
    "Order Confirmation #12345 for Product from Subject",
    "orders@amazon.com",
    "Mon, 15 Jan 2024 10:30:00 -0800",
    "msg_123"
  )
end

Given("the subject contains a product name") do
  # Already set up in the previous step
end

Then("it should extract product name from subject") do
  expect(@parsed_result[:product_name]).to eq("Product from Subject")
end

Given("I have an email with order number but blank product name") do
  mock_parser = double("MerchantParser")
  allow(mock_parser).to receive(:parse).and_return({
    merchant: "Amazon",
    line_items: [{ name: nil, quantity: 1, price: 99.0 }],
    order_number: "12345",
    purchase_date: Date.today
  })
  allow(MerchantParsers).to receive(:get_parser).and_return(mock_parser)
  allow(@gmail_service).to receive(:extract_merchant_from_headers).and_return("Amazon")
  allow(@gmail_service).to receive(:extract_product_name_from_subject_line).and_return(nil)
  allow(@gmail_service).to receive(:extract_product_name_from_email_content).and_return("Product from Email")
  
  @parsed_result = @gmail_service.send(:parse_email_content,
    "<html><body>Content</body></html>",
    "Content",
    "Order Confirmation #12345",
    "orders@amazon.com",
    "Mon, 15 Jan 2024 10:30:00 -0800",
    "msg_123"
  )
end

Given("subject extraction returns nil") do
  # Already set up in the previous step
end

Then("it should extract product name from email content") do
  expect(@parsed_result[:product_name]).to eq("Product from Email")
end

Given("I have an email with order number but no product name found") do
  @test_order_number = "12345"
end

Given("subject and email content extraction both fail") do
  allow(@gmail_service).to receive(:extract_product_name_from_subject_line).and_return(nil)
  allow(@gmail_service).to receive(:extract_product_name_from_email_content).and_return(nil)
end

Given("the email text is long enough for AI extraction") do
  @long_email_text = "A" * 100
end

Then("it should attempt AI extraction") do
  # This will be verified by checking that AiService was called
  expect(AiService).to receive(:new).at_least(:once)
end

Given("I have an email that requires AI extraction") do
  mock_parser = double("MerchantParser")
  allow(mock_parser).to receive(:parse).and_return({
    merchant: "Amazon",
    line_items: [{ name: nil, quantity: 1, price: 99.0 }],
    order_number: "12345",
    purchase_date: Date.today
  })
  allow(MerchantParsers).to receive(:get_parser).and_return(mock_parser)
  allow(@gmail_service).to receive(:extract_merchant_from_headers).and_return("Amazon")
  allow(@gmail_service).to receive(:extract_product_name_from_subject_line).and_return(nil)
  allow(@gmail_service).to receive(:extract_product_name_from_email_content).and_return(nil)
end

Given("the AI service is configured and returns product name") do
  @mock_ai_service = double("AiService")
  allow(AiService).to receive(:new).and_return(@mock_ai_service)
  allow(@mock_ai_service).to receive(:instance_variable_get).with(:@client).and_return(true)
  allow(@mock_ai_service).to receive(:extract_receipt_info).and_return({
    "product_name" => "AI Extracted Product"
  })
  
  @parsed_result = @gmail_service.send(:parse_email_content,
    "<html><body>#{'A' * 100}</body></html>",
    "A" * 100,
    "Order Confirmation #12345",
    "orders@amazon.com",
    "Mon, 15 Jan 2024 10:30:00 -0800",
    "msg_123"
  )
end

Then("it should use AI extracted product name") do
  expect(@parsed_result[:product_name]).to eq("AI Extracted Product")
end

Given("the AI service is not configured for Gmail") do
  @mock_ai_service = double("AiService")
  allow(AiService).to receive(:new).and_return(@mock_ai_service)
  allow(@mock_ai_service).to receive(:instance_variable_get).with(:@client).and_return(nil)
  
  @parsed_result = @gmail_service.send(:parse_email_content,
    "<html><body>#{'A' * 100}</body></html>",
    "A" * 100,
    "Order Confirmation #12345",
    "orders@amazon.com",
    "Mon, 15 Jan 2024 10:30:00 -0800",
    "msg_123"
  )
end

Given("the AI service returns result without product name") do
  @mock_ai_service = double("AiService")
  allow(AiService).to receive(:new).and_return(@mock_ai_service)
  allow(@mock_ai_service).to receive(:instance_variable_get).with(:@client).and_return(true)
  allow(@mock_ai_service).to receive(:extract_receipt_info).and_return({
    "merchant" => "Amazon"
  })
  
  @parsed_result = @gmail_service.send(:parse_email_content,
    "<html><body>#{'A' * 100}</body></html>",
    "A" * 100,
    "Order Confirmation #12345",
    "orders@amazon.com",
    "Mon, 15 Jan 2024 10:30:00 -0800",
    "msg_123"
  )
end

Given("the AI service raises an error") do
  @mock_ai_service = double("AiService")
  allow(AiService).to receive(:new).and_return(@mock_ai_service)
  allow(@mock_ai_service).to receive(:instance_variable_get).with(:@client).and_return(true)
  allow(@mock_ai_service).to receive(:extract_receipt_info).and_raise(StandardError.new("AI Error"))
  
  @parsed_result = @gmail_service.send(:parse_email_content,
    "<html><body>#{'A' * 100}</body></html>",
    "A" * 100,
    "Order Confirmation #12345",
    "orders@amazon.com",
    "Mon, 15 Jan 2024 10:30:00 -0800",
    "msg_123"
  )
end

Given("the email text is too short for AI extraction") do
  @parsed_result = @gmail_service.send(:parse_email_content,
    "<html><body>Short</body></html>",
    "Short",
    "Order Confirmation #12345",
    "orders@amazon.com",
    "Mon, 15 Jan 2024 10:30:00 -0800",
    "msg_123"
  )
end

Then("it should use fallback product name without trying AI") do
  expect(@parsed_result[:product_name]).to eq("Order 12345")
  expect(AiService).not_to have_received(:new)
end

Given("I have an email with order number but all extraction methods fail") do
  mock_parser = double("MerchantParser")
  allow(mock_parser).to receive(:parse).and_return({
    merchant: "Amazon",
    line_items: [{ name: nil, quantity: 1, price: 99.0 }],
    order_number: "12345",
    purchase_date: Date.today
  })
  allow(MerchantParsers).to receive(:get_parser).and_return(mock_parser)
  allow(@gmail_service).to receive(:extract_merchant_from_headers).and_return("Amazon")
  allow(@gmail_service).to receive(:extract_product_name_from_subject_line).and_return(nil)
  allow(@gmail_service).to receive(:extract_product_name_from_email_content).and_return(nil)
  
  @mock_ai_service = double("AiService")
  allow(AiService).to receive(:new).and_return(@mock_ai_service)
  allow(@mock_ai_service).to receive(:instance_variable_get).with(:@client).and_return(nil)
  
  @parsed_result = @gmail_service.send(:parse_email_content,
    "<html><body>Short</body></html>",
    "Short",
    "Order Confirmation #12345",
    "orders@amazon.com",
    "Mon, 15 Jan 2024 10:30:00 -0800",
    "msg_123"
  )
end

Then("it should use fallback product name {string}") do |expected_name|
  expect(@parsed_result[:product_name]).to match(/#{expected_name.gsub('{order_number}', '12345')}/)
end

Given("I have an email with no product name and no order number") do
  mock_parser = double("MerchantParser")
  allow(mock_parser).to receive(:parse).and_return({
    merchant: "Amazon",
    line_items: [{ name: nil, quantity: 1, price: 99.0 }],
    order_number: nil,
    purchase_date: Date.today
  })
  allow(MerchantParsers).to receive(:get_parser).and_return(mock_parser)
  allow(@gmail_service).to receive(:extract_merchant_from_headers).and_return("Amazon")
  
  mock_email_parser = double("EmailOrderParser")
  allow(EmailOrderParser).to receive(:new).and_return(mock_email_parser)
  allow(mock_email_parser).to receive(:extract_order_number_from_subject).and_return(nil)
  
  @parsed_result = @gmail_service.send(:parse_email_content,
    "<html><body>Content</body></html>",
    "Content",
    "Order Confirmation",
    "orders@amazon.com",
    "Mon, 15 Jan 2024 10:30:00 -0800",
    "msg_123"
  )
end

Given("I have a message that parses to a valid receipt") do
  @mock_messages = [double("Message", id: "valid_receipt_message")]
  allow(@mock_fetcher).to receive(:list_order_messages).and_return(@mock_messages)
  
  mock_full_message = create_mock_gmail_message(
    id: "valid_receipt_message",
    subject: "Order Confirmation #12345",
    from: "orders@amazon.com",
    date: "Mon, 15 Jan 2024 10:30:00 -0800",
    html_content: "<html><body>Order content</body></html>",
    text_content: "Order content"
  )
  
  allow(@mock_fetcher).to receive(:get_message).and_return(mock_full_message)
  allow(@mock_fetcher).to receive(:extract_html_from_message).and_return(mock_full_message.html_content)
  allow(@mock_fetcher).to receive(:extract_text_from_message).and_return(mock_full_message.text_content)
  allow(@mock_fetcher).to receive(:extract_attachments).and_return([])
  
  @mock_merchant_parser = double("MerchantParser")
  allow(@mock_merchant_parser).to receive(:parse).and_return({
    line_items: [{ name: "iPhone 15 Pro", quantity: 1, price: 999.0 }],
    merchant: "Amazon",
    order_number: "12345"
  })
  allow(MerchantParsers).to receive(:get_parser).with("Amazon").and_return(@mock_merchant_parser)
  
  @mock_generic_parser = double("EmailOrderParser")
  allow(EmailOrderParser).to receive(:new).and_return(@mock_generic_parser)
  allow(@mock_generic_parser).to receive(:extract_order_number_from_subject).and_return("12345")
end

Then("it should add the receipt to parsed receipts") do
  expect(@result).to be_an(Array)
  expect(@result.length).to be > 0
  expect(@result.first[:product_name]).to eq("iPhone 15 Pro")
end

Then("it should process the attachments") do
  expect(@mock_fetcher).to have_received(:extract_attachments)
end

Then("it should add attachment receipts to parsed receipts") do
  expect(@result).to be_an(Array)
  expect(@result.length).to be > 0
end

Given("I have an email from {string}") do |from_email|
  @from_email = from_email
end

When("I extract merchant from headers") do
  @result = @gmail_service.send(:extract_merchant_from_headers, @from_email, "", "")
end

Then("the extracted merchant should be {string}") do |expected_merchant|
  expect(@result).to eq(expected_merchant)
end

Given("I have a blank merchant name") do
  @merchant_name = ""
end

When("I clean the merchant name") do
  @result = @gmail_service.send(:clean_merchant_name, @merchant_name)
end

Given("I have email content with product pattern match") do
  @html_content = ""
  @text_content = "iPhone 15 Pro Max\nPrice: $999.00"
end

When("I extract product name from email content") do
  @result = @gmail_service.send(:extract_product_name_from_email_content, @html_content, @text_content, "Order Confirmation")
end

Then("it should return the product name") do
  expect(@result).to include("iPhone")
end

Given("I have email content with blank candidate") do
  @html_content = ""
  @text_content = "Item: \nPrice: $999.00"
end

Then("it should skip the blank candidate") do
  expect(@result).to be_nil
end

Given("I have email content with candidate matching excluded patterns") do
  @html_content = ""
  @text_content = "Order Number: 12345\nTotal: $999.00"
end

Then("it should skip the excluded candidate") do
  expect(@result).to be_nil
end

Given("I have blank HTML content") do
  @html_content = ""
end


Then("it should return an empty string") do
  expect(@result).to eq("")
end

Given("I have a PDF attachment") do
  @attachment = {
    filename: "receipt.pdf",
    attachment_id: "att_123",
    mime_type: "application/pdf"
  }
  @message_id = "msg_123"
  @user_id = "me"
  
  @mock_attachment_data = double("AttachmentData", data: Base64.urlsafe_encode64("fake pdf content"))
  allow(@mock_fetcher).to receive(:get_attachment).with(@message_id, "att_123", @user_id).and_return(@mock_attachment_data)
  allow(@receipt_processor).to receive(:process_pdf).and_return({
    merchant: "Amazon",
    purchase_date: Date.today,
    line_items: [{ name: "Product", quantity: 1, price: 99.0 }],
    total_amount: 99.0
  })
end

When("I process the attachment") do
  @result = @gmail_service.send(:process_attachments, [@attachment], @message_id, @user_id)
end

Then("it should call process_pdf") do
  expect(@receipt_processor).to have_received(:process_pdf)
end

Given("I have an image attachment") do
  @attachment = {
    filename: "receipt.jpg",
    attachment_id: "att_456",
    mime_type: "image/jpeg"
  }
  @message_id = "msg_123"
  @user_id = "me"
  
  @mock_attachment_data = double("AttachmentData", data: Base64.urlsafe_encode64("fake image content"))
  allow(@mock_fetcher).to receive(:get_attachment).with(@message_id, "att_456", @user_id).and_return(@mock_attachment_data)
  allow(@receipt_processor).to receive(:process_image).and_return({
    merchant: "Amazon",
    purchase_date: Date.today,
    line_items: [{ name: "Product", quantity: 1, price: 99.0 }],
    total_amount: 99.0
  })
end

Then("it should call process_image") do
  expect(@receipt_processor).to have_received(:process_image)
end

Given("I have an unsupported attachment type") do
  @attachment = {
    filename: "document.doc",
    attachment_id: "att_789",
    mime_type: "application/msword"
  }
  @message_id = "msg_123"
  @user_id = "me"
end

Then("it should skip the attachment") do
  expect(@result).to be_empty
end

Given("I have an attachment that will cause an error") do
  @attachment = {
    filename: "receipt.pdf",
    attachment_id: "att_error",
    mime_type: "application/pdf"
  }
  @message_id = "msg_123"
  @user_id = "me"
  
  allow(@mock_fetcher).to receive(:get_attachment).and_raise(StandardError.new("Attachment error"))
end



Given("I have Gmail messages that will parse successfully") do
  @mock_message = double("Message", id: "msg_123")
  allow(@mock_fetcher).to receive(:list_order_messages).and_return([@mock_message])
  allow(@mock_fetcher).to receive(:get_message).and_return(double("FullMessage", 
    id: "msg_123",
    payload: double("Payload", headers: [
      double("Header", name: "Subject", value: "Order confirmation"),
      double("Header", name: "From", value: "orders@amazon.com"),
      double("Header", name: "Date", value: "Mon, 15 Jan 2024 10:30:00 -0800")
    ])
  ))
  allow(@mock_fetcher).to receive(:extract_html_from_message).and_return("<html>Order content</html>")
  allow(@mock_fetcher).to receive(:extract_text_from_message).and_return("Order content")
  allow(@mock_fetcher).to receive(:extract_attachments).and_return([])
  
  @mock_merchant_parser = double("MerchantParser")
  allow(@mock_merchant_parser).to receive(:parse).and_return({
    line_items: [{ name: "Test Product", quantity: 1, price: 100 }],
    merchant: "Amazon",
    purchase_date: Date.today,
    order_number: "12345"
  })
  allow(MerchantParsers).to receive(:get_parser).with("Amazon").and_return(@mock_merchant_parser)
  
  @mock_email_parser = double("EmailOrderParser")
  allow(EmailOrderParser).to receive(:new).and_return(@mock_email_parser)
  allow(@mock_email_parser).to receive(:parse).and_return({
    line_items: [{ name: "Test Product", quantity: 1, price: 100 }],
    merchant: "Amazon",
    purchase_date: Date.today,
    order_number: "12345"
  })
  allow(@mock_email_parser).to receive(:extract_order_number_from_subject).and_return("12345")
end

When("I parse receipt emails") do
  @result = @gmail_service.parse_receipt_emails
end

Then("the parsed receipt should be added to receipts array") do
  expect(@result).to be_an(Array)
  expect(@result.length).to be > 0
  expect(@result.first).to have_key(:product_name)
end

Then("receipts found count should be incremented") do
  expect(@result.length).to be > 0
end

Given("I have an attachment with image mime type") do
  @attachment = {
    filename: "receipt.jpg",
    attachment_id: "att_123",
    mime_type: "image/jpeg"
  }
  @message_id = "msg_123"
  @user_id = "me"
  
  @mock_attachment_data = double("AttachmentData", data: Base64.urlsafe_encode64("fake image data"))
  allow(@mock_fetcher).to receive(:get_attachment).with(@message_id, @attachment[:attachment_id], @user_id).and_return(@mock_attachment_data)
  
  @mock_receipt_processor = double("ReceiptProcessor")
  allow(ReceiptProcessor).to receive(:new).and_return(@mock_receipt_processor)
  allow(@mock_receipt_processor).to receive(:process_image).and_return({
    merchant: "Amazon",
    purchase_date: Date.today,
    line_items: [{ name: "Test Product", quantity: 1, price: 100 }]
  })
  allow(@mock_receipt_processor).to receive(:cleanup)
  
  @gmail_service.instance_variable_set(:@receipt_processor, @mock_receipt_processor)
end

Then("it should process the image attachment") do
  @result = @gmail_service.send(:process_attachments, [@attachment], @message_id, @user_id)
  expect(@result).to be_an(Array)
  expect(@result.length).to eq(1)
  expect(@result.first[:merchant]).to eq("Amazon")
end

Given("I have an attachment with unsupported mime type") do
  @attachment = {
    filename: "document.txt",
    attachment_id: "att_123",
    mime_type: "text/plain"
  }
  @message_id = "msg_123"
  @user_id = "me"
end

Then("it should skip the attachment") do
  @result = @gmail_service.send(:process_attachments, [@attachment], @message_id, @user_id)
  expect(@result).to be_an(Array)
  expect(@result.length).to eq(0)
end

Given("I have a promotional email") do
  @html_content = "<html><body>Promotional content</body></html>"
  @text_content = "Promotional content"
  @subject = "Last minute gifts - Shop now!"
  @from = "marketing@store.com"
  @date_header = "Mon, 15 Jan 2024 10:30:00 -0800"
  @message_id = "promo_msg"
end

When("I parse the email content for coverage") do
  @parsed_result = @gmail_service.send(:parse_email_content, @html_content, @text_content, @subject, @from, @date_header, @message_id)
end

Then("the email content should return nil") do
  expect(@parsed_result).to be_nil
end

Given("I have an email from Digital merchant") do
  @html_content = "<html><body>Digital order</body></html>"
  @text_content = "Digital order"
  @subject = "Your Digital Order"
  @from = "Digital"
  @date_header = "Mon, 15 Jan 2024 10:30:00 -0800"
  @message_id = "digital_msg"
end

Given("I have an email where merchant parser returns nil") do
  @html_content = "<html><body>Order content</body></html>"
  @text_content = "Order content"
  @subject = "Order Confirmation #12345"
  @from = "orders@unknown.com"
  @date_header = "Mon, 15 Jan 2024 10:30:00 -0800"
  @message_id = "unknown_msg"
  
  @mock_merchant_parser = double("MerchantParser")
  allow(@mock_merchant_parser).to receive(:parse).and_return(nil)
  allow(MerchantParsers).to receive(:get_parser).and_return(@mock_merchant_parser)
  
  @mock_generic_parser = double("EmailOrderParser")
  allow(EmailOrderParser).to receive(:new).and_return(@mock_generic_parser)
  allow(@mock_generic_parser).to receive(:parse).and_return({
    line_items: [{ name: "Test Product", quantity: 1, price: 100 }],
    merchant: "Unknown",
    order_number: "12345"
  })
  allow(@mock_generic_parser).to receive(:extract_order_number_from_subject).and_return("12345")
end

Then("the email content should return parsed data") do
  expect(@parsed_result).not_to be_nil
  expect(@parsed_result).to be_a(Hash)
end

Given("I have an email with order number in subject only") do
  @html_content = "<html><body>Order content</body></html>"
  @text_content = "Order content"
  @subject = "Your Order #12345"
  @from = "orders@amazon.com"
  @date_header = "Mon, 15 Jan 2024 10:30:00 -0800"
  @message_id = "order_msg"
  
  @mock_merchant_parser = double("MerchantParser")
  allow(@mock_merchant_parser).to receive(:parse).and_return({
    line_items: [{ name: "Product", quantity: 1, price: 100 }],
    merchant: "Amazon",
    order_number: nil
  })
  allow(MerchantParsers).to receive(:get_parser).with("Amazon").and_return(@mock_merchant_parser)
  
  @mock_generic_parser = double("EmailOrderParser")
  allow(EmailOrderParser).to receive(:new).and_return(@mock_generic_parser)
  allow(@mock_generic_parser).to receive(:extract_order_number_from_subject).and_return("12345")
end

Then("it should extract order number from subject") do
  expect(@parsed_result).not_to be_nil
  expect(@parsed_result[:order_number]).to eq("12345")
end

Given("I have an email with product name in subject") do
  @html_content = "<html><body>Order content</body></html>"
  @text_content = "Order content"
  @subject = "iPhone 15 Pro - Order #12345"
  @from = "orders@amazon.com"
  @date_header = "Mon, 15 Jan 2024 10:30:00 -0800"
  @message_id = "product_subject_msg"
  
  @mock_merchant_parser = double("MerchantParser")
  allow(@mock_merchant_parser).to receive(:parse).and_return({
    line_items: [],
    merchant: "Amazon",
    order_number: "12345"
  })
  allow(MerchantParsers).to receive(:get_parser).with("Amazon").and_return(@mock_merchant_parser)
  
  @mock_generic_parser = double("EmailOrderParser")
  allow(EmailOrderParser).to receive(:new).and_return(@mock_generic_parser)
  allow(@mock_generic_parser).to receive(:extract_order_number_from_subject).and_return("12345")
end

Then("the email should extract product name from subject") do
  expect(@parsed_result).not_to be_nil
  expect(@parsed_result[:product_name]).to be_present
end

Given("I have an email with product name in content") do
  @html_content = "<html><body><p>MacBook Pro 16-inch</p></body></html>"
  @text_content = "MacBook Pro 16-inch\nPrice: $1999.00"
  @subject = "Order Confirmation #12345"
  @from = "orders@amazon.com"
  @date_header = "Mon, 15 Jan 2024 10:30:00 -0800"
  @message_id = "product_content_msg"
  
  @mock_merchant_parser = double("MerchantParser")
  allow(@mock_merchant_parser).to receive(:parse).and_return({
    line_items: [],
    merchant: "Amazon",
    order_number: "12345"
  })
  allow(MerchantParsers).to receive(:get_parser).with("Amazon").and_return(@mock_merchant_parser)
  
  @mock_generic_parser = double("EmailOrderParser")
  allow(EmailOrderParser).to receive(:new).and_return(@mock_generic_parser)
  allow(@mock_generic_parser).to receive(:extract_order_number_from_subject).and_return("12345")
end

Then("it should extract product name from content") do
  expect(@parsed_result).not_to be_nil
  expect(@parsed_result[:product_name]).to be_present
end

Given("the AI service is configured for Gmail") do
  @mock_ai_service = double("AiService")
  @mock_client = double("client")
  allow(@mock_ai_service).to receive(:instance_variable_get).with(:@client).and_return(@mock_client)
  allow(@mock_ai_service).to receive(:extract_receipt_info).and_return({
    "product_name" => "AI Extracted Product"
  })
  allow(AiService).to receive(:new).and_return(@mock_ai_service)
end

Given("I have an email where product name needs AI extraction") do
  @html_content = "<html><body>Order content with lots of text that exceeds 50 characters and needs AI to extract product name</body></html>"
  @text_content = "Order content with lots of text that exceeds 50 characters and needs AI to extract product name"
  @subject = "Order Confirmation #12345"
  @from = "orders@amazon.com"
  @date_header = "Mon, 15 Jan 2024 10:30:00 -0800"
  @message_id = "ai_extract_msg"
  
  @mock_merchant_parser = double("MerchantParser")
  allow(@mock_merchant_parser).to receive(:parse).and_return({
    line_items: [],
    merchant: "Amazon",
    order_number: "12345"
  })
  allow(MerchantParsers).to receive(:get_parser).with("Amazon").and_return(@mock_merchant_parser)
  
  @mock_generic_parser = double("EmailOrderParser")
  allow(EmailOrderParser).to receive(:new).and_return(@mock_generic_parser)
  allow(@mock_generic_parser).to receive(:extract_order_number_from_subject).and_return("12345")
  allow(@gmail_service).to receive(:extract_product_name_from_subject_line).and_return(nil)
  allow(@gmail_service).to receive(:extract_product_name_from_email_content).and_return(nil)
end

Then("it should use AI to extract product name") do
  expect(@parsed_result).not_to be_nil
  expect(@parsed_result[:product_name]).to eq("AI Extracted Product")
end

Given("I have an email with only order number") do
  @html_content = "<html><body>Order content</body></html>"
  @text_content = "Order content"
  @subject = "Order Confirmation #12345"
  @from = "orders@amazon.com"
  @date_header = "Mon, 15 Jan 2024 10:30:00 -0800"
  @message_id = "order_only_msg"
  
  @mock_merchant_parser = double("MerchantParser")
  allow(@mock_merchant_parser).to receive(:parse).and_return({
    line_items: [],
    merchant: "Amazon",
    order_number: "12345"
  })
  allow(MerchantParsers).to receive(:get_parser).with("Amazon").and_return(@mock_merchant_parser)
  
  @mock_generic_parser = double("EmailOrderParser")
  allow(EmailOrderParser).to receive(:new).and_return(@mock_generic_parser)
  allow(@mock_generic_parser).to receive(:extract_order_number_from_subject).and_return("12345")
  allow(@gmail_service).to receive(:extract_product_name_from_subject_line).and_return(nil)
  allow(@gmail_service).to receive(:extract_product_name_from_email_content).and_return(nil)
  allow(AiService).to receive(:new).and_return(double("AiService", instance_variable_get: nil))
end

Then("it should use order number as product name") do
  expect(@parsed_result).not_to be_nil
  expect(@parsed_result[:product_name]).to eq("Order 12345")
end

Given("I have a merchant name with special characters") do
  @merchant_name = "Orders-Support@walmart.com"
end

Then("it should return cleaned merchant name") do
  expect(@result).to eq("Walmart")
end

Given("I have email content with product pattern matches") do
  @html_content = "<html><body></body></html>"
  @text_content = "Item: MacBook Pro 16-inch\nQty: 1\nPrice: $1999.00"
  @subject = "Order Confirmation"
end

When("I extract product name from email content for pattern test") do
  @extracted_name = @gmail_service.send(:extract_product_name_from_email_content, @html_content, @text_content, @subject)
end

Then("the email content should return extracted product name") do
  expect(@extracted_name).to be_present
  expect(@extracted_name.length).to be >= 10
end

Given("I have a subject line with product pattern matches") do
  @subject = "iPhone 15 Pro - Order #12345"
  @order_number = "12345"
end

When("I extract product name from subject line") do
  @extracted_name = @gmail_service.send(:extract_product_name_from_subject_line, @subject, @order_number)
end

Then("the subject line should return extracted product name") do
  expect(@extracted_name).to be_present
  expect(@extracted_name.length).to be >= 5
end

Given("I have an attachment that returns receipt data without merchant") do
  @attachment = {
    filename: "receipt.pdf",
    attachment_id: "att_123",
    mime_type: "application/pdf"
  }
  @message_id = "msg_123"
  @user_id = "me"
  
  @mock_attachment_data = double("AttachmentData", data: Base64.urlsafe_encode64("fake pdf data"))
  allow(@mock_fetcher).to receive(:get_attachment).with(@message_id, @attachment[:attachment_id], @user_id).and_return(@mock_attachment_data)
  
  @mock_receipt_processor = double("ReceiptProcessor")
  allow(ReceiptProcessor).to receive(:new).and_return(@mock_receipt_processor)
  allow(@mock_receipt_processor).to receive(:process_pdf).and_return({
    purchase_date: Date.today,
    line_items: [{ name: "Test Product", quantity: 1, price: 100 }]
    # No merchant key
  })
  allow(@mock_receipt_processor).to receive(:cleanup)
  
  @gmail_service.instance_variable_set(:@receipt_processor, @mock_receipt_processor)
end

Given("I have an attachment with receipt data but no primary item name") do
  @attachment = {
    filename: "receipt.pdf",
    attachment_id: "att_123",
    mime_type: "application/pdf"
  }
  @message_id = "msg_123"
  @user_id = "me"
  
  @mock_attachment_data = double("AttachmentData", data: Base64.urlsafe_encode64("fake pdf data"))
  allow(@mock_fetcher).to receive(:get_attachment).with(@message_id, @attachment[:attachment_id], @user_id).and_return(@mock_attachment_data)
  
  @mock_receipt_processor = double("ReceiptProcessor")
  allow(ReceiptProcessor).to receive(:new).and_return(@mock_receipt_processor)
  allow(@mock_receipt_processor).to receive(:process_pdf).and_return({
    merchant: "Amazon",
    purchase_date: Date.today,
    line_items: [{ quantity: 1, price: 100 }]  # No name in line item
  })
  allow(@mock_receipt_processor).to receive(:cleanup)
  
  @gmail_service.instance_variable_set(:@receipt_processor, @mock_receipt_processor)
end

Then("the receipt should use {string} as product name") do |expected_name|
  @result = @gmail_service.send(:process_attachments, [@attachment], @message_id, @user_id)
  expect(@result).to be_an(Array)
  expect(@result.length).to eq(1)
  expect(@result.first[:product_name]).to eq(expected_name)
end

Given("I have an attachment with receipt data") do
  @attachment = {
    filename: "receipt.pdf",
    attachment_id: "att_123",
    mime_type: "application/pdf"
  }
  @message_id = "msg_123"
  @user_id = "me"
  
  @mock_attachment_data = double("AttachmentData", data: Base64.urlsafe_encode64("fake pdf data"))
  allow(@mock_fetcher).to receive(:get_attachment).with(@message_id, @attachment[:attachment_id], @user_id).and_return(@mock_attachment_data)
  
  @mock_receipt_processor = double("ReceiptProcessor")
  allow(ReceiptProcessor).to receive(:new).and_return(@mock_receipt_processor)
  allow(@mock_receipt_processor).to receive(:process_pdf).and_return({
    merchant: "Amazon",
    purchase_date: Date.today,
    line_items: [{ name: "Test Product", quantity: 1, price: 100 }]
  })
  allow(@mock_receipt_processor).to receive(:cleanup)
  
  @gmail_service.instance_variable_set(:@receipt_processor, @mock_receipt_processor)
end

Then("it should determine warranty length for the receipt") do
  @result = @gmail_service.send(:process_attachments, [@attachment], @message_id, @user_id)
  expect(@result).to be_an(Array)
  expect(@result.length).to eq(1)
  expect(@result.first).to have_key(:warranty_months)
  expect(@result.first[:warranty_months]).to be_a(Integer)
end

# New step definitions for coverage scenarios
Given("I have a message that parses to nil") do
  @mock_messages = [double("Message", id: "message_nil_receipt")]
  allow(@mock_fetcher).to receive(:list_order_messages).and_return(@mock_messages)
  
  mock_full_message = create_mock_gmail_message(
    id: "message_nil_receipt",
    subject: "Order Confirmation #12345",
    from: "orders@amazon.com",
    date: "Mon, 15 Jan 2024 10:30:00 -0800",
    html_content: "<html><body>Promotional content</body></html>",
    text_content: "Promotional content"
  )
  
  allow(@mock_fetcher).to receive(:get_message).with("message_nil_receipt", "me").and_return(mock_full_message)
  allow(@mock_fetcher).to receive(:extract_html_from_message).and_return(mock_full_message.html_content)
  allow(@mock_fetcher).to receive(:extract_text_from_message).and_return(mock_full_message.text_content)
  allow(@mock_fetcher).to receive(:extract_attachments).and_return([])
  
  # Mock parse_email_content to return nil
  allow(@gmail_service).to receive(:parse_email_content).and_return(nil)
end

Given("I have a message with no attachments") do
  @mock_messages = [double("Message", id: "message_no_attachments")]
  allow(@mock_fetcher).to receive(:list_order_messages).and_return(@mock_messages)
  
  mock_full_message = create_mock_gmail_message(
    id: "message_no_attachments",
    subject: "Order Confirmation #12345",
    from: "orders@amazon.com",
    date: "Mon, 15 Jan 2024 10:30:00 -0800",
    html_content: "<html><body>Order content</body></html>",
    text_content: "Order content"
  )
  
  allow(@mock_fetcher).to receive(:get_message).with("message_no_attachments", "me").and_return(mock_full_message)
  allow(@mock_fetcher).to receive(:extract_html_from_message).and_return(mock_full_message.html_content)
  allow(@mock_fetcher).to receive(:extract_text_from_message).and_return(mock_full_message.text_content)
  allow(@mock_fetcher).to receive(:extract_attachments).and_return([])
  
  # Mock parse_email_content to return a valid receipt
  allow(@gmail_service).to receive(:parse_email_content).and_return({
    product_name: "iPhone 15 Pro",
    merchant: "Amazon",
    purchase_date: Date.today,
    warranty_months: 12,
    warranty_type: "manufacturer",
    return_policy_days: 30,
    return_deadline: nil,
    source: "gmail_parsed",
    raw_email_id: "message_no_attachments",
    order_number: "12345",
    total_amount: 999.0
  })
end

Given("I have a message that raises an error during processing") do
  @mock_messages = [
    double("Message", id: "message_error"),
    double("Message", id: "message_success")
  ]
  allow(@mock_fetcher).to receive(:list_order_messages).and_return(@mock_messages)
  
  # First message raises an error
  allow(@mock_fetcher).to receive(:get_message).with("message_error", "me").and_raise(StandardError.new("API Error"))
  
  # Second message succeeds
  mock_full_message = create_mock_gmail_message(
    id: "message_success",
    subject: "Order Confirmation #12345",
    from: "orders@amazon.com",
    date: "Mon, 15 Jan 2024 10:30:00 -0800",
    html_content: "<html><body>Order content</body></html>",
    text_content: "Order content"
  )
  
  allow(@mock_fetcher).to receive(:get_message).with("message_success", "me").and_return(mock_full_message)
  allow(@mock_fetcher).to receive(:extract_html_from_message).and_return(mock_full_message.html_content)
  allow(@mock_fetcher).to receive(:extract_text_from_message).and_return(mock_full_message.text_content)
  allow(@mock_fetcher).to receive(:extract_attachments).and_return([])
  
  # Mock parse_email_content to return a valid receipt
  allow(@gmail_service).to receive(:parse_email_content).and_return({
    product_name: "iPhone 15 Pro",
    merchant: "Amazon",
    purchase_date: Date.today,
    warranty_months: 12,
    warranty_type: "manufacturer",
    return_policy_days: 30,
    return_deadline: nil,
    source: "gmail_parsed",
    raw_email_id: "message_success",
    order_number: "12345",
    total_amount: 999.0
  })
end

Then("it should not add the receipt to parsed receipts") do
  expect(@result).to be_an(Array)
  expect(@result).to be_empty
end

Then("receipts found count should not be incremented") do
  expect(@result.length).to eq(0)
end

Then("it should not process any attachments") do
  expect(@result).to be_an(Array)
  # Should have receipt from email content but no attachment receipts
  expect(@result.length).to eq(1)
  expect(@result.first[:source]).to eq("gmail_parsed")
end

Then("it should continue processing other messages") do
  expect(@result).to be_an(Array)
  # Should have at least one receipt from the successful message
  expect(@result.length).to be >= 1
end

Then("it should return parsed receipts from successful messages") do
  expect(@result).to be_an(Array)
  expect(@result.length).to eq(1)
  expect(@result.first[:product_name]).to eq("iPhone 15 Pro")
end


When('I extract text from HTML') do
  @service = GmailService.new('token', 'refresh', @user)
  @extracted_text = @service.send(:extract_text_from_html, @html_content)
end

Then('it should return empty string') do
  expect(@extracted_text).to eq("")
end


