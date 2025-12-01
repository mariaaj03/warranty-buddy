Feature: Application Job
  As a system
  I want to process background jobs
  So I can handle async tasks

  Scenario: ApplicationJob can be instantiated
    When I instantiate ApplicationJob
    Then it should be an instance of ApplicationJob
    And it should be an instance of ActiveJob::Base

  Scenario: ApplicationJob can be inherited
    When I create a test job that inherits from ApplicationJob
    Then the test job should be a subclass of ApplicationJob
    And the test job should be a subclass of ActiveJob::Base
