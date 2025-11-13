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
  
  puts "DEBUG: Subject parsing - subject: #{subject}"
  puts "DEBUG: Subject parsing - content: #{text_content}"
  puts "DEBUG: Subject parsing - is_order_email?: #{@parser.is_order_email?}"
  
  @is_order_email = @parser.is_order_email?
  @parsed_data = @parser.parse if @is_order_email
  
  puts "DEBUG: Parsed data: #{@parsed_data.inspect}"
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
  
  puts "DEBUG: From email: #{from_email}"
  puts "DEBUG: Is order email?: #{@parser.is_order_email?}"
  
  @parsed_data = @parser.parse
  
  puts "DEBUG: Parsed data: #{@parsed_data.inspect}"
end

Then("the merchant should be extracted as {string}") do |expected_merchant|
  puts "DEBUG: @parsed_data = #{@parsed_data.inspect}"
  puts "DEBUG: Expected merchant = #{expected_merchant}"
  puts "DEBUG: From email = #{@parser.instance_variable_get(:@from)}"
  
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
  
  puts "DEBUG: Meta tag parsing - is_order_email?: #{@parser.is_order_email?}"
  
  @parsed_data = @parser.parse
  
  puts "DEBUG: Parsed data: #{@parsed_data.inspect}"
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
  
  puts "DEBUG: Order parsing - content: #{full_content}"
  puts "DEBUG: Order parsing - is_order_email?: #{@parser.is_order_email?}"
  
  @parsed_data = @parser.parse
  
  puts "DEBUG: Parsed data: #{@parsed_data.inspect}"
end

Then("the order number should be extracted as {string}") do |expected_order_number|
  puts "DEBUG: @parsed_data = #{@parsed_data.inspect}"
  puts "DEBUG: Expected order number = #{expected_order_number}"
  puts "DEBUG: Text content = #{@parser.instance_variable_get(:@text)}"
  
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
  
  puts "DEBUG: Date parsing - content: #{content}"
  puts "DEBUG: Date parsing - is_order_email?: #{@parser.is_order_email?}"
  
  @parsed_data = @parser.parse
  
  puts "DEBUG: Parsed data: #{@parsed_data.inspect}"
end

Then("the purchase date should be parsed as {string}") do |expected_date|
  puts "DEBUG: @parsed_data = #{@parsed_data.inspect}"
  puts "DEBUG: Expected date = #{expected_date}"
  
  if @parsed_data.nil?
    fail "Expected parsed data but got nil. Parser may have rejected this as non-order email."
  end
  
  if @parsed_data[:purchase_date].nil?
    fail "Expected purchase_date in parsed data but got nil. Available keys: #{@parsed_data.keys}. Text content: #{@parser.instance_variable_get(:@text)}"
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
  
  puts "DEBUG: Product table parsing - is_order_email?: #{@parser.is_order_email?}"
  
  @parsed_data = @parser.parse
  
  puts "DEBUG: Parsed data: #{@parsed_data.inspect}"
end

Then("I should extract {int} line items") do |expected_count|
  expect(@parsed_data[:line_items].count).to eq(expected_count)
end

Then("the first item should be {string} with quantity {int} and price {float}") do |name, quantity, price|
  first_item = @parsed_data[:line_items].first
  expect(first_item[:name]).to eq(name)
  expect(first_item[:quantity]).to eq(quantity) 
  expect(first_item[:price]).to eq(price)
end

Then("the second item should be {string} with quantity {int} and price {float}") do |name, quantity, price|
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
    
    puts "DEBUG: Price parsing for #{row['input']} - is_order_email?: #{parser.is_order_email?}"
    
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
    puts "DEBUG: Full result for #{result[:input]}: #{result.inspect}"
    
    # Check if the price might be stored under a different key
    parsed_data = @price_results.find { |r| r[:input] == result[:input] }
    # You might need to check other keys like :amount, :price, :total, etc.
    
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
    
    puts "DEBUG: Merchant parsing for #{row['domain']} - is_order_email?: #{parser.is_order_email?}"
    
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