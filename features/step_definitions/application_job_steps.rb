When("I instantiate ApplicationJob") do
  @job_instance = ApplicationJob.new
end

Then("it should be an instance of ApplicationJob") do
  expect(@job_instance).to be_an_instance_of(ApplicationJob)
end

Then("it should be an instance of ActiveJob::Base") do
  expect(@job_instance).to be_a(ActiveJob::Base)
end

Given("I have an ApplicationJob instance") do
  @job_instance = ApplicationJob.new
end

When("I check if it responds to ActiveJob methods") do
  # This step is just for documentation - the actual checks are in the Then steps
end

Then("it should respond to {string}") do |method_name|
  # perform_later and perform_now are class methods, not instance methods
  if method_name == "perform_later" || method_name == "perform_now"
    expect(ApplicationJob).to respond_to(method_name.to_sym)
  else
    expect(@job_instance).to respond_to(method_name.to_sym)
  end
end

When("I create a test job that inherits from ApplicationJob") do
  # Create a test job class dynamically
  @test_job_class = Class.new(ApplicationJob) do
    def perform(*args)
      # Test job implementation
    end
  end
  @test_job_instance = @test_job_class.new
end

Then("the test job should be a subclass of ApplicationJob") do
  expect(@test_job_class.ancestors).to include(ApplicationJob)
end

Then("the test job should be a subclass of ActiveJob::Base") do
  expect(@test_job_class.ancestors).to include(ActiveJob::Base)
end

