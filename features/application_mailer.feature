Feature: Application Mailer
  As a system
  I want to send emails
  So users can receive notifications

  Scenario: ApplicationMailer can be instantiated
    When I instantiate ApplicationMailer
    Then it should be an instance of ApplicationMailer
    And it should be an instance of ActionMailer::Base

  Scenario: ApplicationMailer has default from address
    When I check the default from address
    Then it should be "from@example.com"

  Scenario: ApplicationMailer has mailer layout
    When I check the layout
    Then it should use "mailer" layout

  Scenario: ApplicationMailer can be inherited
    When I create a test mailer that inherits from ApplicationMailer
    Then the test mailer should be a subclass of ApplicationMailer
    And the test mailer should be a subclass of ActionMailer::Base
