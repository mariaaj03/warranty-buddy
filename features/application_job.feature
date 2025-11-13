Feature: Application Job
  As a system
  I want ApplicationJob to be a base class for background jobs
  So that jobs can inherit common behavior

  Scenario: ApplicationJob can be instantiated
    When I instantiate ApplicationJob
    Then it should be an instance of ApplicationJob
    And it should be an instance of ActiveJob::Base

  Scenario: ApplicationJob responds to ActiveJob methods
    Given I have an ApplicationJob instance
    When I check if it responds to ActiveJob methods
    Then it should respond to "perform"
    And it should respond to "perform_later"
    And it should respond to "perform_now"

  Scenario: ApplicationJob can be subclassed
    When I create a test job that inherits from ApplicationJob
    Then the test job should be a subclass of ApplicationJob
    And the test job should be a subclass of ActiveJob::Base

