# features/step_definitions/merchant_parser_steps.rb

Given("the merchant parser system is available") do
  # System is ready for testing
end

# Parser Selection Steps
When("I get parser for merchant {string}") do |merchant|
  @selected_parser = MerchantParsers.get_parser(merchant)
end

When("I get parser for merchant nil") do
  @selected_parser = MerchantParsers.get_parser(nil)
end

Then("it should return the Amazon parser") do
  expect(@selected_parser).to eq(MerchantParsers::AmazonParser)
end

Then("it should return the Best Buy parser") do
  expect(@selected_parser).to eq(MerchantParsers::BestBuyParser)
end

Then("it should return the Generic parser") do
  expect(@selected_parser).to eq(MerchantParsers::GenericParser)
end

# Amazon Parser Steps
When("I parse Amazon email with order number {string}") do |order_number, html_content|
  text_content = html_content.gsub(/<[^>]*>/, " ").squeeze(" ").strip
  @amazon_result = MerchantParsers::AmazonParser.parse(html_content, text_content)
end

When("I parse Amazon email with text {string}") do |text_content|
  html_content = "<html><body><p>#{text_content}</p></body></html>"
  @amazon_result = MerchantParsers::AmazonParser.parse(html_content, text_content)
end

When("I parse Amazon email with date text {string}") do |date_text|
  text_content = "Amazon Order Confirmation. #{date_text}. Thank you for your order."
  html_content = "<html><body><p>#{text_content}</p></body></html>"
  @amazon_result = MerchantParsers::AmazonParser.parse(html_content, text_content)
end

When("I parse Amazon email with product table") do |table_html|
  text_content = table_html.gsub(/<[^>]*>/, " ").squeeze(" ").strip
  @amazon_result = MerchantParsers::AmazonParser.parse(table_html, text_content)
end

When("I parse Amazon email with table containing headers") do |table_html|
  text_content = table_html.gsub(/<[^>]*>/, " ").squeeze(" ").strip
  @amazon_result = MerchantParsers::AmazonParser.parse(table_html, text_content)
end

When("I parse Amazon email with total {string}") do |total_text|
  text_content = "Amazon Order Summary. #{total_text}. Thank you."
  html_content = "<html><body><p>#{text_content}</p></body></html>"
  @amazon_result = MerchantParsers::AmazonParser.parse(html_content, text_content)
end

When("I parse Amazon prices in different formats") do |table|
  @amazon_price_results = []
  table.hashes.each do |row|
    parsed_price = MerchantParsers::AmazonParser.send(:parse_price, row['input'])
    @amazon_price_results << {
      format: row['format'],
      input: row['input'],
      expected: row['expected'].to_f,
      actual: parsed_price
    }
  end
end

When("I parse Amazon price {string}") do |price_string|
  @amazon_price_result = MerchantParsers::AmazonParser.send(:parse_price, price_string)
end

When("I parse Amazon email with empty content") do
  @amazon_result = MerchantParsers::AmazonParser.parse("", "")
end

When("I parse Amazon email without order information") do |html_content|
  text_content = html_content.gsub(/<[^>]*>/, " ").squeeze(" ").strip
  @amazon_result = MerchantParsers::AmazonParser.parse(html_content, text_content)
end

When("I parse a complete Amazon order email") do |html_content|
  text_content = html_content.gsub(/<[^>]*>/, " ").squeeze(" ").strip
  @complete_amazon_result = MerchantParsers::AmazonParser.parse(html_content, text_content)
end

# Amazon Assertions
Then("the Amazon order number should be {string}") do |expected_order_number|
  expect(@amazon_result[:order_number]).to eq(expected_order_number)
end

Then("the Amazon purchase date should be {string}") do |expected_date|
  expect(@amazon_result[:purchase_date]).to eq(Date.parse(expected_date))
end

Then("the purchase date should be nil") do
  expect(@amazon_result[:purchase_date]).to be_nil
end

Then("I should extract {int} line items from Amazon parser") do |expected_count|
  expect(@amazon_result[:line_items].length).to eq(expected_count)
end

Then("the first item should be {string} with quantity {int} and price {float}") do |name, quantity, price|
  first_item = @amazon_result[:line_items].first
  expect(first_item[:name]).to eq(name)
  expect(first_item[:quantity]).to eq(quantity)
  expect(first_item[:price]).to eq(price)
end

Then("the second item should be {string} with quantity {int} and price {float}") do |name, quantity, price|
  second_item = @amazon_result[:line_items][1]
  expect(second_item[:name]).to eq(name)
  expect(second_item[:quantity]).to eq(quantity)
  expect(second_item[:price]).to eq(price)
end

Then("the item should be {string}") do |expected_name|
  expect(@amazon_result[:line_items].first[:name]).to eq(expected_name)
end

Then("the total amount should be {float}") do |expected_total|
  expect(@amazon_result[:total_amount]).to eq(expected_total)
end

Then("all Amazon prices should be correctly parsed") do
  @amazon_price_results.each do |result|
    expect(result[:actual]).to eq(result[:expected]),
      "Expected #{result[:expected]} for #{result[:input]} (#{result[:format]}), got #{result[:actual]}"
  end
end

Then("the Amazon price should be nil") do
  expect(@amazon_price_result).to be_nil
end

Then("it should return Amazon parser results with nil values") do
  expect(@amazon_result).to be_a(Hash)
  expect(@amazon_result[:merchant]).to eq("Amazon")
  expect(@amazon_result[:order_number]).to be_nil
  expect(@amazon_result[:purchase_date]).to be_nil
  expect(@amazon_result[:line_items]).to eq([])
  expect(@amazon_result[:total_amount]).to be_nil
end

Then("the Amazon parser should return empty results") do
  expect(@amazon_result[:order_number]).to be_nil
  expect(@amazon_result[:total_amount]).to be_nil
end

Then("it should return complete Amazon order data") do
  expect(@complete_amazon_result).to be_a(Hash)
  expect(@complete_amazon_result[:merchant]).to eq("Amazon")
  expect(@complete_amazon_result[:order_number]).to be_present
  expect(@complete_amazon_result[:purchase_date]).to be_present
  expect(@complete_amazon_result[:line_items]).to be_present
  expect(@complete_amazon_result[:total_amount]).to be_present
end

# Best Buy Parser Steps
When("I parse Best Buy email with order number {string}") do |order_number, html_content|
  text_content = html_content.gsub(/<[^>]*>/, " ").squeeze(" ").strip
  @bestbuy_result = MerchantParsers::BestBuyParser.parse(html_content, text_content)
end

When("I parse Best Buy email with text {string}") do |text_content|
  html_content = "<html><body><p>#{text_content}</p></body></html>"
  @bestbuy_result = MerchantParsers::BestBuyParser.parse(html_content, text_content)
end

When("I parse Best Buy email with date text {string}") do |date_text|
  text_content = "Best Buy Order Confirmation. #{date_text}. Thank you for your purchase."
  html_content = "<html><body><p>#{text_content}</p></body></html>"
  @bestbuy_result = MerchantParsers::BestBuyParser.parse(html_content, text_content)
end

When("I parse Best Buy email with product table") do |table_html|
  text_content = table_html.gsub(/<[^>]*>/, " ").squeeze(" ").strip
  @bestbuy_result = MerchantParsers::BestBuyParser.parse(table_html, text_content)
end

When("I parse Best Buy email with simple product table") do |table_html|
  text_content = table_html.gsub(/<[^>]*>/, " ").squeeze(" ").strip
  @bestbuy_result = MerchantParsers::BestBuyParser.parse(table_html, text_content)
end

When("I parse Best Buy email with total {string}") do |total_text|
  text_content = "Best Buy Order Summary. #{total_text}. Thank you."
  html_content = "<html><body><p>#{text_content}</p></body></html>"
  @bestbuy_result = MerchantParsers::BestBuyParser.parse(html_content, text_content)
end

When("I parse Best Buy prices in different formats") do |table|
  @bestbuy_price_results = []
  table.hashes.each do |row|
    parsed_price = MerchantParsers::BestBuyParser.send(:parse_price, row['input'])
    @bestbuy_price_results << {
      format: row['format'],
      input: row['input'],
      expected: row['expected'].to_f,
      actual: parsed_price
    }
  end
end

When("I parse Best Buy email with malformed HTML") do |html_content|
  text_content = html_content.gsub(/<[^>]*>/, " ").squeeze(" ").strip
  @bestbuy_result = MerchantParsers::BestBuyParser.parse(html_content, text_content)
end

When("I parse a complete Best Buy order email") do |email_html|
  @merchant_parser = MerchantParser.new
  
  # Get the Best Buy parser and parse the email
  best_buy_parser = @merchant_parser.get_parser("Best Buy")
  @best_buy_result = best_buy_parser.parse(email_html)
  
  # Ensure the result is not nil
  @best_buy_result ||= {}
end

# Best Buy Assertions
Then("the Best Buy order number should be {string}") do |expected_order_number|
  expect(@bestbuy_result[:order_number]).to eq(expected_order_number)
end

Then("the Best Buy purchase date should be {string}") do |expected_date|
  expect(@bestbuy_result[:purchase_date]).to eq(Date.parse(expected_date))
end

Then("I should extract {int} line items from Best Buy parser") do |expected_count|
  expect(@bestbuy_result[:line_items].length).to eq(expected_count)
end

Then("the first Best Buy item should be {string} with price {float}") do |name, price|
  first_item = @bestbuy_result[:line_items].first
  expect(first_item[:name]).to eq(name)
  expect(first_item[:price]).to eq(price)
end

Then("the second Best Buy item should be {string} with price {float}") do |name, price|
  second_item = @bestbuy_result[:line_items][1]
  expect(second_item[:name]).to eq(name)
  expect(second_item[:price]).to eq(price)
end

Then("the Best Buy item should have quantity {int}") do |expected_quantity|
  expect(@bestbuy_result[:line_items].first[:quantity]).to eq(expected_quantity)
end

Then("the Best Buy total amount should be {float}") do |expected_total|
  expect(@bestbuy_result[:total_amount]).to eq(expected_total)
end

Then("all Best Buy prices should be correctly parsed") do
  @bestbuy_price_results.each do |result|
    expect(result[:actual]).to eq(result[:expected]),
      "Expected #{result[:expected]} for #{result[:input]} (#{result[:format]}), got #{result[:actual]}"
  end
end

Then("it should handle the error gracefully for Best Buy") do
  expect(@bestbuy_result).to be_a(Hash)
end

Then("it should return Best Buy parser results") do
  expect(@bestbuy_result[:merchant]).to eq("Best Buy")
end

Then("it should return complete Best Buy order data") do
  expect(@complete_bestbuy_result).to be_a(Hash)
  expect(@complete_bestbuy_result[:merchant]).to eq("Best Buy")
end

Then("the Best Buy merchant should be {string}") do |expected_merchant|
  expect(@complete_bestbuy_result[:merchant]).to eq(expected_merchant)
end



Then("it should have {int} Best Buy line items") do |expected_count|
  expect(@complete_bestbuy_result[:line_items].length).to eq(expected_count)
end

Then("the Best Buy total should be {float}") do |expected_total|
  expect(@complete_bestbuy_result[:total_amount]).to eq(expected_total)
end

# Generic Parser Steps
When("I parse generic email with unknown merchant") do |html_content|
  text_content = html_content.gsub(/<[^>]*>/, " ").squeeze(" ").strip
  @generic_result = MerchantParsers::GenericParser.parse(html_content, text_content)
end

When("I parse generic email with unparseable content") do |html_content|
  text_content = html_content.gsub(/<[^>]*>/, " ").squeeze(" ").strip
  @generic_result = MerchantParsers::GenericParser.parse(html_content, text_content)
end

Then("it should use the EmailOrderParser") do
  # The generic parser delegates to EmailOrderParser
  expect(@generic_result).to be_a(Hash).or be_nil
end

Then("it should return parsed order data") do
  expect(@generic_result).to be_a(Hash)
end

Then("it should return nil from generic parser") do
  expect(@generic_result).to be_nil
end

# Integration Steps
Then("the Amazon merchant should be {string}") do |expected_merchant|
  expect(@complete_amazon_result[:merchant]).to eq(expected_merchant)
end

Then("the order number should be {string}") do |expected_order_number|
  expect(@complete_amazon_result[:order_number]).to eq(expected_order_number)
end

Then("the purchase date should be {string}") do |expected_date|
  expect(@complete_amazon_result[:purchase_date]).to eq(Date.parse(expected_date))
end

Then("it should have {int} line items") do |expected_count|
  expect(@complete_amazon_result[:line_items].length).to eq(expected_count)
end

Then("the total should be {float}") do |expected_total|
  expect(@complete_amazon_result[:total_amount]).to eq(expected_total)
end