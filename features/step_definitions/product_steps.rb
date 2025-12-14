# Product model step definitions

Given("I have a signed in user") do
  @user = User.create!(
    email: 'test@example.com',
    password: 'password123',
    password_confirmation: 'password123'
  )
end

Given("I have a product with purchase date {string} and warranty {string} months") do |purchase_date, warranty_months|
  @product = Product.create!(
    user: @user,
    product_name: "Test Product",
    merchant: "Test Merchant",
    purchase_date: Date.parse(purchase_date),
    warranty_months: warranty_months.to_i
  )
end

Given("I have a product without purchase date") do
  @product = Product.create!(
    user: @user,
    product_name: "Test Product",
    merchant: "Test Merchant",
    purchase_date: nil,
    warranty_months: 12
  )
end

Given("I have a product without warranty months") do
  @product = Product.create!(
    user: @user,
    product_name: "Test Product",
    merchant: "Test Merchant",
    purchase_date: Date.today,
    warranty_months: nil
  )
end

Given("I have a product expiring in {int} days") do |days|
  expiry_date = Date.current + days.days
  purchase_date = expiry_date - 12.months
  @product = Product.create!(
    user: @user,
    product_name: "Test Product",
    merchant: "Test Merchant",
    purchase_date: purchase_date,
    warranty_months: 12
  )
end

Given("I have a product without expiry date") do
  @product = Product.create!(
    user: @user,
    product_name: "Test Product",
    merchant: "Test Merchant",
    purchase_date: nil,
    warranty_months: nil
  )
end

Given("I have a product that expired {int} days ago") do |days|
  expiry_date = Date.current - days.days
  purchase_date = expiry_date - 12.months
  @product = Product.create!(
    user: @user,
    product_name: "Test Product",
    merchant: "Test Merchant",
    purchase_date: purchase_date,
    warranty_months: 12
  )
  @product.reload
end

Given("I have a product expiring today") do
  purchase_date = Date.current - 12.months
  @product = Product.create!(
    user: @user,
    product_name: "Test Product",
    merchant: "Test Merchant",
    purchase_date: purchase_date,
    warranty_months: 12
  )
end

Given("I have an active product") do
  @product = Product.create!(
    user: @user,
    product_name: "Test Product",
    merchant: "Test Merchant",
    purchase_date: Date.today,
    warranty_months: 12,
    warranty_type: nil
  )
end

Given("I have an active product with warranty type {string}") do |warranty_type|
  @product = Product.create!(
    user: @user,
    product_name: "Test Product",
    merchant: "Test Merchant",
    purchase_date: Date.today,
    warranty_months: 12,
    warranty_type: warranty_type
  )
end

Given("the AI service is configured for product") do
  @mock_ai_service = instance_double(AiService)
  @mock_client = double("client")
  allow(@mock_ai_service).to receive(:instance_variable_get).with(:@client).and_return(@mock_client)
  allow(@mock_ai_service).to receive(:check_warranty_eligibility).and_return({
    "is_covered" => true,
    "reasoning" => "This issue is covered under warranty",
    "recommended_action" => "Contact manufacturer"
  })
  allow(AiService).to receive(:new).and_return(@mock_ai_service)
end

Given("the AI service is stubbed to verify it is not called") do
  # Stub AiService to ensure it's not called when warranty is expired
  allow(AiService).to receive(:new).and_raise("AiService should not be called when warranty is expired")
end

When("I calculate the expiry date") do
  @expiry_date = @product.expiry_date
end

Then("it should return a date {int} months after purchase date") do |months|
  # The expiry_date method uses >> operator which adds months
  # For a product with purchase_date "2024-01-15" and warranty_months 12,
  # expiry_date should be "2025-01-15"
  expected_date = @product.purchase_date >> @product.warranty_months
  expect(@expiry_date).to eq(expected_date)
end

Then("the expiry date should be nil") do
  expect(@expiry_date).to be_nil
end

Then("the days until expiry should be nil") do
  expect(@days_until_expiry).to be_nil
end

When("I calculate days until expiry") do
  @days_until_expiry = @product.days_until_expiry
end

Then("it should return {int} days") do |expected_days|
  expect(@days_until_expiry).to eq(expected_days)
end

When("I check the product status") do
  @status = @product.status
end

Then("it should return {string}") do |expected_status|
  expect(@status).to eq(expected_status)
end

When("I check if warranty is eligible") do
  @is_eligible = @product.warranty_eligible?
end

Then("it should return true") do
  expect(@is_eligible).to be true
end

Then("it should return false") do
  expect(@is_eligible).to be false
end

When("I check warranty eligibility for issue {string}") do |issue_description|
  @eligibility_result = @product.check_warranty_eligibility(issue_description)
end

Then("it should return eligible false with reason {string}") do |reason|
  expect(@eligibility_result).not_to be_nil, "Expected a hash but got nil. Product warranty_eligible? = #{@product.warranty_eligible?}, expiry_date = #{@product.expiry_date}"
  expect(@eligibility_result).to be_a(Hash)
  # The method returns a hash with symbol keys when warranty expired
  eligible = @eligibility_result[:eligible] || @eligibility_result["eligible"]
  result_reason = @eligibility_result[:reason] || @eligibility_result["reason"]
  expect(eligible).to eq(false)
  expect(result_reason).to eq(reason)
end

Then("it should call the AI service") do
  expect(@mock_ai_service).to have_received(:check_warranty_eligibility)
end

Then("it should pass the product name and issue description") do
  expect(@mock_ai_service).to have_received(:check_warranty_eligibility) do |product_name, issue_description, warranty_terms|
    expect(product_name).to eq(@product.product_name)
    expect(issue_description).to eq("broken screen")
  end
end

Then("it should use {string} warranty type when warranty_type is nil") do |default_type|
  expect(@mock_ai_service).to have_received(:check_warranty_eligibility) do |product_name, issue_description, warranty_terms|
    expect(warranty_terms).to include(default_type)
    expect(warranty_terms).to include(@product.product_name)
  end
end

Then("it should use {string} warranty type in warranty terms") do |warranty_type|
  expect(@mock_ai_service).to have_received(:check_warranty_eligibility) do |product_name, issue_description, warranty_terms|
    expect(warranty_terms).to include(warranty_type)
    expect(warranty_terms).to include(@product.product_name)
  end
end

Then("the AI service should not be called") do
  # Verify that AiService.new was not called (the method should return early)
  # The method should return early with { eligible: false, reason: "Warranty expired" }
  # before reaching the line that calls AiService.new
  # Only check if we stubbed it
  if defined?(@mock_ai_service) && @mock_ai_service
    expect(@mock_ai_service).not_to have_received(:check_warranty_eligibility) if @mock_ai_service.respond_to?(:check_warranty_eligibility)
  end
end

Given("I have a product with name {string} and merchant {string}") do |product_name, merchant|
  @product = Product.create!(
    user: @user,
    product_name: product_name,
    merchant: merchant,
    purchase_date: Date.today,
    warranty_months: 12
  )
end

When("I check the category icon") do
  @category_icon = @product.category_icon
end

Then("the category icon should be {string}") do |expected_icon|
  expect(@category_icon).to eq(expected_icon)
end

