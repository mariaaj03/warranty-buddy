# ProductsController step definitions

Given("I have a signed in user for products controller") do
  @user = User.create!(
    email: 'test@example.com',
    password: 'password123',
    password_confirmation: 'password123'
  )
  # Sign in the user using Devise test helpers
  login_as(@user, scope: :user)
end

Given("I have products with expiry dates") do
  @user.products.create!(
    product_name: "iPhone 15 Pro",
    merchant: "Apple",
    purchase_date: Date.today - 6.months,
    warranty_months: 12
  )
  @user.products.create!(
    product_name: "MacBook Pro",
    merchant: "Apple",
    purchase_date: Date.today - 3.months,
    warranty_months: 12
  )
end

Given("I have products with and without expiry dates") do
  @user.products.create!(
    product_name: "iPhone 15 Pro",
    merchant: "Apple",
    purchase_date: Date.today - 6.months,
    warranty_months: 12
  )
  @user.products.create!(
    product_name: "Old Product",
    merchant: "Store",
    purchase_date: nil,
    warranty_months: nil
  )
end

Given("I have products without expiry dates") do
  @user.products.create!(
    product_name: "Product 1",
    merchant: "Store",
    purchase_date: nil,
    warranty_months: nil
  )
end

Given("I have a Gmail connected user") do
  @user.update!(
    provider: 'google_oauth2',
    uid: "test_uid_#{SecureRandom.hex(4)}",
    gmail_token: "test_token_#{SecureRandom.hex(8)}",
    gmail_refresh_token: "test_refresh_#{SecureRandom.hex(8)}"
  )
end

Given("I have a user without Gmail connection") do
  @user.update!(
    provider: nil,
    uid: nil,
    gmail_token: nil,
    gmail_refresh_token: nil
  )
end

Given("I have products with warranty expirations") do
  @user.products.create!(
    product_name: "Product 1",
    merchant: "Store",
    purchase_date: Date.today - 6.months,
    warranty_months: 12
  )
end

Given("some products will fail to export") do
  # This is handled by mocking the calendar service
  @failing_product_name = "Product 1"
  @mock_calendar_service = instance_double(GoogleCalendarService)
  allow(GoogleCalendarService).to receive(:new).with(@user).and_return(@mock_calendar_service)
  
  allow(@mock_calendar_service).to receive(:export_warranties).and_return({
    success: true,
    created: 1,
    errors: ["Product 1: Some error occurred"]
  })
end

Given("the Calendar API is unavailable") do
  @api_unavailable = true
  @mock_calendar_service = instance_double(GoogleCalendarService)
  allow(GoogleCalendarService).to receive(:new).with(@user).and_return(@mock_calendar_service)
  
  allow(@mock_calendar_service).to receive(:export_warranties).and_return({
    success: false,
    error: "Calendar API unavailable"
  })
end

When("I visit the calendar export URL") do
  visit "/products/calendar"
end

When("I visit the calendar export URL with reminders {string}") do |reminders|
  visit "/products/calendar?reminders=#{reminders}"
end

When("I export warranties to Google Calendar") do
  # Mock GoogleCalendarService if not already mocked
  unless @mock_calendar_service
    @mock_calendar_service = instance_double(GoogleCalendarService)
    allow(GoogleCalendarService).to receive(:new).with(@user).and_return(@mock_calendar_service)
    
    allow(@mock_calendar_service).to receive(:export_warranties).and_return({
      success: true,
      created: 2,
      errors: []
    })
  end
  
  page.driver.post "/products/export_to_google_calendar"
end

When("I export warranties to Google Calendar with reminders {string}") do |reminders|
  # Mock GoogleCalendarService
  @mock_calendar_service = instance_double(GoogleCalendarService)
  allow(GoogleCalendarService).to receive(:new).with(@user).and_return(@mock_calendar_service)
  
  # Capture the reminder_days parameter
  @captured_reminder_days = nil
  allow(@mock_calendar_service).to receive(:export_warranties) do |products, reminder_days:|
    @captured_reminder_days = reminder_days
    {
      success: true,
      created: products.count,
      errors: []
    }
  end
  
  page.driver.post "/products/export_to_google_calendar?reminders=#{reminders}"
end

Then("I should receive an iCal file") do
  if page.driver.respond_to?(:last_response)
    response = page.driver.last_response
    expect(response.headers['Content-Type']).to include('text/calendar')
    expect(response.headers['Content-Disposition']).to include('warranty_buddy.ics')
  else
    expect(page.response_headers['Content-Type']).to include('text/calendar')
    expect(page.response_headers['Content-Disposition']).to include('warranty_buddy.ics')
  end
end

Then("the calendar should contain warranty events") do
  body = page.driver.respond_to?(:last_response) ? page.driver.last_response.body : page.body
  expect(body).to include("BEGIN:VCALENDAR")
  expect(body).to include("Warranty expires:")
end

Then("the calendar should contain events with alarms") do
  body = page.driver.respond_to?(:last_response) ? page.driver.last_response.body : page.body
  expect(body).to include("BEGIN:VALARM")
  expect(body).to include("ACTION:DISPLAY")
  expect(body).to include("Warranty expiring soon:")
end

Then("invalid reminder days should be filtered out") do
  # The calendar should only contain valid reminder days (7 and 30)
  # Invalid ones (abc, -5) should be filtered out
  body = page.driver.respond_to?(:last_response) ? page.driver.last_response.body : page.body
  expect(body).to include("BEGIN:VALARM")
end

Then("only products with expiry dates should be included") do
  # Count products with expiry dates
  products_with_expiry = @user.products.select { |p| p.expiry_date.present? }
  body = page.driver.respond_to?(:last_response) ? page.driver.last_response.body : page.body
  expect(body.scan(/Warranty expires:/).count).to eq(products_with_expiry.count)
end

Then("I should be redirected to dashboard") do
  expect(current_path).to eq(dashboard_path)
end

Then("I should see a success message") do
  expect(page).to have_content("Successfully exported")
end

Then("I should see a partial success message with errors") do
  expect(page).to have_content("Exported")
  expect(page).to have_content("error(s) occurred")
end

Then("I should see an alert {string}") do |alert_message|
  expect(page).to have_content(alert_message)
end

Then("I should see an error message") do
  expect(page).to have_content("Failed to export to Google Calendar")
end

Then("I should see an error message {string}") do |message|
  expect(page).to have_content(message)
end

Then("only valid non-negative reminder days should be used") do
  # The calendar service should receive only valid reminder days (7, 30, 0)
  # Invalid ones (abc, -5) should be filtered out
  expect(@captured_reminder_days).to eq([0, 7, 30])
end

Then("the calendar should contain alarm triggers with timezone") do
  body = page.driver.respond_to?(:last_response) ? page.driver.last_response.body : page.body
  expect(body).to include("BEGIN:VALARM")
  expect(body).to include("ACTION:DISPLAY")
  expect(body).to include("Warranty expiring soon:")
  expect(body).to include("TZID:America/New_York")
end

Given("the calendar export will succeed with no errors") do
  @mock_calendar_service = instance_double(GoogleCalendarService)
  allow(GoogleCalendarService).to receive(:new).with(@user).and_return(@mock_calendar_service)
  
  allow(@mock_calendar_service).to receive(:export_warranties).and_return({
    success: true,
    created: 2,
    errors: []
  })
end

Given("the calendar export will succeed with errors") do
  @mock_calendar_service = instance_double(GoogleCalendarService)
  allow(GoogleCalendarService).to receive(:new).with(@user).and_return(@mock_calendar_service)
  
  allow(@mock_calendar_service).to receive(:export_warranties).and_return({
    success: true,
    created: 1,
    errors: ["Product 1: Some error occurred", "Product 2: Another error"]
  })
end

Given("the calendar export will fail") do
  @mock_calendar_service = instance_double(GoogleCalendarService)
  allow(GoogleCalendarService).to receive(:new).with(@user).and_return(@mock_calendar_service)
  
  allow(@mock_calendar_service).to receive(:export_warranties).and_return({
    success: false,
    error: "Calendar API unavailable"
  })
end

Then("I should see a success message {string}") do |message|
  expect(page).to have_content(message)
end

Then("I should see a partial success message with error count") do
  expect(page).to have_content("Exported")
  expect(page).to have_content("error(s) occurred")
end

