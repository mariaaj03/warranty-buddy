When("I instantiate ApplicationMailer") do
  # ApplicationMailer is a class, not typically instantiated
  # But we can test that it's a class and can be instantiated
  @mailer_class = ApplicationMailer
  @mailer_instance = ApplicationMailer.new
end

Then("it should be an instance of ApplicationMailer") do
  expect(@mailer_instance).to be_an_instance_of(ApplicationMailer)
end

Then("it should be an instance of ActionMailer::Base") do
  expect(@mailer_instance).to be_a(ActionMailer::Base)
end

Given("I have an ApplicationMailer instance") do
  @mailer_class = ApplicationMailer
  @mailer_instance = ApplicationMailer.new
end

When("I check the default from address") do
  # This step is just for documentation - the actual check is in the Then step
end

Then("it should have default from {string}") do |from_address|
  expect(ApplicationMailer.default[:from]).to eq(from_address)
end

When("I check the layout") do
  # This step is just for documentation - the actual check is in the Then step
end

Then("it should have layout {string}") do |layout_name|
  expect(ApplicationMailer._layout).to eq(layout_name)
end

When("I create a test mailer that inherits from ApplicationMailer") do
  # Create a test mailer class dynamically
  @test_mailer_class = Class.new(ApplicationMailer) do
    def test_email
      mail(to: "test@example.com", subject: "Test Email")
    end
  end
  @test_mailer_instance = @test_mailer_class.new
end

Then("the test mailer should be a subclass of ApplicationMailer") do
  expect(@test_mailer_class.ancestors).to include(ApplicationMailer)
end

Then("the test mailer should be a subclass of ActionMailer::Base") do
  expect(@test_mailer_class.ancestors).to include(ActionMailer::Base)
end

Then("the test mailer should inherit the default from address") do
  expect(@test_mailer_class.default[:from]).to eq("from@example.com")
end

Then("the test mailer should inherit the mailer layout") do
  expect(@test_mailer_class._layout).to eq("mailer")
end

When("I call a mail method on the test mailer") do
  @mail_object = @test_mailer_class.test_email
end

Then("it should return a mail object") do
  expect(@mail_object).to be_a(ActionMailer::MessageDelivery)
end

Then("the mail object should have the default from address") do
  # Get the actual mail message
  mail_message = @mail_object.message
  expect(mail_message.from).to include("from@example.com")
end

