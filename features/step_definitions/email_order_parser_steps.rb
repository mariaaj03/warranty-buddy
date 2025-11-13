# features/step_definitions/email_parsing_steps.rb
Given("the email parsing system is available") do
  # Setup any necessary test data or configurations
end

When("I parse a promotional email with subject {string}") do |subject|
  @parser = EmailOrderParser.new(
    "<html><body>Shop our amazing deals! Click here now!</body></html>",
    "Shop our amazing deals! Click here now!",
    subject,
    "marketing@store.com"
  )
  @is_order_email = @parser.is_order_email?
  @parsed_data = @parser.parse if @is_order_email
end

Then("the email should be rejected as non-order email") do
  expect(@is_order_email).to be_falsey
end

Then("no parsing data should be returned") do
  expect(@parsed_data).to be_nil
end

When("I parse an email with subject {string}") do |subject|
  # For subject line tests, keep the content simple so the order number comes from the subject
  html_content = "<html><body><h1>Thank you for your order</h1><p>Your order has been processed.</p></body></html>"
  text_content = "Thank you for your order. Your order has been processed."
  
  @parser = EmailOrderParser.new(
    html_content,
    text_content,
    subject,  # This is the key - use the actual subject with the order number
    "orders@amazon.com"
  )
  
  @is_order_email = @parser.is_order_email?
  @parsed_data = @parser.parse if @is_order_email
end

Then("the email should be accepted as an order email") do
  expect(@is_order_email).to be_truthy
end

Then("parsing data should be returned") do
  expect(@parsed_data).not_to be_nil
  expect(@parsed_data).to be_a(Hash)
end

When("I parse an email from {string}") do |from_email|
  html_content = "<html><body><h1>Order Confirmation</h1><p>Your order has been confirmed and will ship soon.</p></body></html>"
  text_content = "Order Confirmation: Your order has been confirmed and will ship soon."
  
  @parser = EmailOrderParser.new(
    html_content,
    text_content,
    "Your Order Confirmation #12345", # More order-like subject
    from_email
  )
  
  @parsed_data = @parser.parse
end

Then("the merchant should be extracted as {string}") do |expected_merchant|
  if @parsed_data.nil?
    fail "Expected parsed data but got nil. Parser may have rejected this as non-order email."
  end
  
  expect(@parsed_data[:merchant]).to eq(expected_merchant)
end

When("I parse an email with meta tag site_name {string}") do |site_name|
  html_content = %(<html><head><meta property="og:site_name" content="#{site_name}"></head><body><h1>Order Confirmation</h1><p>Your order has been confirmed.</p></body></html>)
  text_content = "Order Confirmation: Your order has been confirmed."
  
  @parser = EmailOrderParser.new(
    html_content,
    text_content,
    "Your Order Confirmation #12345", # Order-like subject
    "orders@store.com"
  )
  
  @parsed_data = @parser.parse
end

When("I parse an email containing {string}") do |content|
  # Make it more order-like
  full_content = "Order Confirmation: #{content}. Thank you for your purchase!"
  html_content = "<html><body><h1>Order Confirmation</h1><p>#{full_content}</p></body></html>"
  
  @parser = EmailOrderParser.new(
    html_content,
    full_content,
    "Your Order Confirmation", # Order-like subject
    "orders@store.com"
  )
  
  @parsed_data = @parser.parse
end

Then("the order number should be extracted as {string}") do |expected_order_number|
  if @parsed_data.nil?
    fail "Expected parsed data but got nil. Parser may have rejected this as non-order email."
  end
  
  expect(@parsed_data[:order_number]).to eq(expected_order_number)
end

When("I parse an email with purchase date {string}") do |date_string|
  # Make the email content more realistic to pass is_order_email? check
  content = "Your order confirmation. Order Date: #{date_string}. Thank you for your purchase!"
  html_content = "<html><body><h1>Order Confirmation</h1><p>#{content}</p></body></html>"
  
  @parser = EmailOrderParser.new(
    html_content,
    content,
    "Your Order Confirmation #12345", # More order-like subject
    "orders@store.com"
  )
  
  @parsed_data = @parser.parse
end

Then("the purchase date should be parsed as {string}") do |expected_date|
  if @parsed_data.nil?
    fail "Expected parsed data but got nil. Parser may have rejected this as non-order email."
  end
  
  if @parsed_data[:purchase_date].nil?
    fail "Expected purchase_date in parsed data but got nil. Available keys: #{@parsed_data.keys}."
  end
  
  expect(@parsed_data[:purchase_date]).to eq(Date.parse(expected_date))
end

When("I parse an email with HTML product table") do |table_html|
  html_content = "<html><body><h1>Order Confirmation</h1><p>Your order details:</p>#{table_html}<p>Thank you for your purchase!</p></body></html>"
  text_content = "Order Confirmation: iPhone 15 Pro 1 $999.00 AirPods Pro 2 $249.00"
  
  @parser = EmailOrderParser.new(
    html_content,
    text_content,
    "Your Order Confirmation #12345", # Order-like subject
    "orders@store.com"
  )
  
  @parsed_data = @parser.parse
end

Then("I should extract {int} email line items") do |expected_count|
  expect(@parsed_data[:line_items].count).to eq(expected_count)
end

Then("the first email item should be {string} with quantity {int} and price {float}") do |name, quantity, price|
  first_item = @parsed_data[:line_items].first
  expect(first_item[:name]).to eq(name)
  expect(first_item[:quantity]).to eq(quantity) 
  expect(first_item[:price]).to eq(price)
end

Then("the second email item should be {string} with quantity {int} and price {float}") do |name, quantity, price|
  second_item = @parsed_data[:line_items][1]
  expect(second_item[:name]).to eq(name)
  expect(second_item[:quantity]).to eq(quantity)
  expect(second_item[:price]).to eq(price)
end

When("I parse prices in different formats") do |table|
  @price_results = []
  
  table.hashes.each do |row|
    content = "Order Confirmation: Your total is #{row['input']}. Thank you!"
    html_content = "<html><body><h1>Order Confirmation</h1><p>#{content}</p></body></html>"
    
    parser = EmailOrderParser.new(
      html_content,
      content,
      "Your Order Confirmation #12345", # Order-like subject
      "orders@store.com"  
    )
    
    parsed_data = parser.parse
    @price_results << {
      format: row['format'],
      input: row['input'], 
      parsed: parsed_data&.dig(:total_amount)
    }
  end
end

Then("all prices should be correctly parsed as numbers") do
  @price_results.each do |result|
    if result[:parsed].nil?
      fail "No price found for #{result[:input]}. This suggests the parser's extract_total_amount method isn't working or the price patterns don't match."
    end
    
    expect(result[:parsed]).to be_a(Numeric), 
      "Expected #{result[:input]} (#{result[:format]}) to parse as number, got #{result[:parsed]} (#{result[:parsed].class})"
  end
end

When("I parse an email with corrupted encoding") do
  corrupted_html = "<html><body>Order \xFF\xFE confirmation</body></html>"
  corrupted_text = "Order \xFF\xFE confirmation"
  
  @parser = EmailOrderParser.new(
    corrupted_html,
    corrupted_text, 
    "Order confirmation",
    "orders@store.com"
  )
end

Then("the system should handle it gracefully") do
  expect { @parser.is_order_email? }.not_to raise_error
  expect { @parser.parse }.not_to raise_error
end

Then("should not raise any exceptions") do
  expect { @parser.is_order_email? }.not_to raise_error
  expect { @parser.parse }.not_to raise_error
end

When("I parse an empty email") do
  @parser = EmailOrderParser.new("", "", "", "")
  @result = @parser.parse
end

Then("it should return nil for parsed data") do
  expect(@result).to be_nil
end

When("I parse emails from common merchants") do |table|
  @merchant_results = []
  
  table.hashes.each do |row|
    html_content = "<html><body><h1>Order Confirmation</h1><p>Your order has been confirmed.</p></body></html>"
    text_content = "Order Confirmation: Your order has been confirmed."
    
    parser = EmailOrderParser.new(
      html_content,
      text_content,
      "Your Order Confirmation #12345", # Order-like subject
      row['domain']
    )
    
    parsed_data = parser.parse
    @merchant_results << {
      domain: row['domain'],
      expected: row['expected_merchant'],
      actual: parsed_data&.dig(:merchant)
    }
  end
end

Then("the merchants should be extracted correctly") do
  @merchant_results.each do |result|
    expect(result[:actual]).to eq(result[:expected]),
      "Expected merchant '#{result[:expected]}' from #{result[:domain]}, got '#{result[:actual]}'"
  end
end

When("I parse an email with order number in subject {string}") do |subject_line|
  # Simple content without order numbers, so extraction must come from subject
  html_content = "<html><body><p>Thank you for your purchase.</p></body></html>"
  text_content = "Thank you for your purchase."
  
  @parser = EmailOrderParser.new(
    html_content,
    text_content,
    subject_line,
    "orders@store.com"
  )
  
  @parsed_data = @parser.parse
end

# Additional coverage scenarios
When("I parse an email with order number and date nearby") do
  html_content = "<html><body><p>Order #12345 placed on January 15, 2024. Thank you!</p></body></html>"
  text_content = "Order #12345 placed on January 15, 2024. Thank you!"
  
  @parser = EmailOrderParser.new(
    html_content,
    text_content,
    "Your Order Confirmation #12345",
    "orders@store.com"
  )
  
  @parsed_data = @parser.parse
end

Then("the purchase date should be extracted from context") do
  expect(@parsed_data[:purchase_date]).to eq(Date.parse("2024-01-15"))
end

When("I parse an email containing {string} for merchant extraction") do |content|
  html_content = "<html><body><p>#{content}</p></body></html>"
  
  @parser = EmailOrderParser.new(
    html_content,
    content,
    "Your Order Confirmation #12345",
    "orders@store.com"
  )
  
  @parsed_data = @parser.parse
end

When("I parse an email with subject {string}") do |subject|
  html_content = "<html><body><p>Your order has been processed.</p></body></html>"
  text_content = "Your order has been processed."
  
  @parser = EmailOrderParser.new(
    html_content,
    text_content,
    subject,
    "orders@store.com"
  )
  
  @is_order_email = @parser.is_order_email?
  @parsed_data = @parser.parse if @is_order_email
end

When("I parse an email containing {string} with quantity") do |content|
  html_content = "<html><body><p>#{content}</p></body></html>"
  
  @parser = EmailOrderParser.new(
    html_content,
    content,
    "Your Order Confirmation #12345",
    "orders@store.com"
  )
  
  @parsed_data = @parser.parse
end

Then("I should extract line items with quantity") do
  expect(@parsed_data[:line_items]).not_to be_empty
  expect(@parsed_data[:line_items].first[:quantity]).to eq(2)
end

When("I parse an email with blank HTML") do
  @parser = EmailOrderParser.new("", "Order confirmation", "Your Order #123", "orders@store.com")
  @parsed_data = @parser.parse
end

When("I parse an email with blank merchant name") do
  html_content = '<html><head><meta property="og:site_name" content=""></head><body>Order</body></html>'
  @parser = EmailOrderParser.new(html_content, "Order", "Your Order #123", "orders@store.com")
  @parsed_data = @parser.parse
end

Then("the merchant should be cleaned to empty string") do
  # The clean_merchant_name method returns "" for blank names
  expect(@parsed_data[:merchant]).to eq("")
end

When("I parse an email with total {string}") do |total_text|
  html_content = "<html><body><p>Order confirmation. #{total_text}</p></body></html>"
  text_content = "Order confirmation. #{total_text}"
  
  @parser = EmailOrderParser.new(
    html_content,
    text_content,
    "Your Order Confirmation #12345",
    "orders@store.com"
  )
  
  @parsed_data = @parser.parse
end

Then("the total amount should be parsed as {float}") do |expected_amount|
  expect(@parsed_data[:total_amount]).to eq(expected_amount)
end

When("I parse an email with blank price") do
  html_content = "<html><body><p>Order confirmation. Total: </p></body></html>"
  text_content = "Order confirmation. Total: "
  
  @parser = EmailOrderParser.new(
    html_content,
    text_content,
    "Your Order Confirmation #12345",
    "orders@store.com"
  )
  
  @parsed_data = @parser.parse
end

Then("the price should be parsed as nil") do
  expect(@parsed_data[:total_amount]).to be_nil
end

Given("Chronic gem is not available") do
  # Stub the require to raise LoadError
  allow(Rails.logger).to receive(:warn)
  # The gem loading happens at class load time, so we can't easily test it
  # But we can verify the code handles missing Chronic gracefully
end

Then("it should log a warning about Chronic gem") do
  expect(Rails.logger).to have_received(:warn).with(/Chronic gem not available/)
end

When("I parse an email with date in table") do
  html_content = """
    <html><body>
    <table>
      <tr><td>Order Date</td><td>January 15, 2024</td></tr>
      <tr><td>Item</td><td>Price</td></tr>
      <tr><td>iPhone 15 Pro</td><td>$999.00</td></tr>
    </table>
    </body></html>
  """
  text_content = html_content.gsub(/<[^>]*>/, " ").squeeze(" ").strip
  @parser = EmailOrderParser.new(html_content, text_content, "Your order confirmation", "orders@store.com")
  @parsed_data = @parser.parse
end

Then("the purchase date should be extracted from table") do
  expect(@parsed_data[:purchase_date]).to eq(Date.parse("2024-01-15"))
end

When("I parse an email containing line item without quantity {string}") do |line_item_text|
  html_content = "<html><body><p>#{line_item_text}</p></body></html>"
  text_content = line_item_text
  @parser = EmailOrderParser.new(html_content, text_content, "Your order", "orders@store.com")
  @parsed_data = @parser.parse
end

Then("the line item should have default quantity 1") do
  expect(@parsed_data[:line_items].first[:quantity]).to eq(1)
end

When("I parse an email containing line item with invalid name") do
  # Create a line item pattern that matches but has nil name
  html_content = "<html><body><p>2x  - $999.00</p></body></html>"
  text_content = "2x  - $999.00"
  @parser = EmailOrderParser.new(html_content, text_content, "Your order", "orders@store.com")
  @parsed_data = @parser.parse
end

Then("the line item should be skipped") do
  # Line items with blank or short names should be skipped
  expect(@parsed_data[:line_items].length).to eq(0)
end

When("I parse an email with table without quantity column") do
  html_content = """
    <html><body>
    <table>
      <tr><th>Item</th><th>Price</th></tr>
      <tr><td>iPhone 15 Pro</td><td>$999.00</td></tr>
    </table>
    </body></html>
  """
  text_content = html_content.gsub(/<[^>]*>/, " ").squeeze(" ").strip
  @parser = EmailOrderParser.new(html_content, text_content, "Your order", "orders@store.com")
  @parsed_data = @parser.parse
end

Then("the line items should have default quantity 1") do
  expect(@parsed_data[:line_items].first[:quantity]).to eq(1)
end

When("I parse an email with table without price column") do
  html_content = """
    <html><body>
    <table>
      <tr><th>Item</th><th>Qty</th></tr>
      <tr><td>iPhone 15 Pro</td><td>1</td></tr>
    </table>
    </body></html>
  """
  text_content = html_content.gsub(/<[^>]*>/, " ").squeeze(" ").strip
  @parser = EmailOrderParser.new(html_content, text_content, "Your order", "orders@store.com")
  @parsed_data = @parser.parse
end

Then("the line items should have nil price") do
  expect(@parsed_data[:line_items].first[:price]).to be_nil
end