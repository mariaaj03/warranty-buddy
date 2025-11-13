Feature: Application Mailer
  As a system
  I want ApplicationMailer to be a base class for mailers
  So that mailers can inherit common behavior

  Scenario: ApplicationMailer can be instantiated
    When I instantiate ApplicationMailer
    Then it should be an instance of ApplicationMailer
    And it should be an instance of ActionMailer::Base

  Scenario: ApplicationMailer has default from address
    Given I have an ApplicationMailer instance
    When I check the default from address
    Then it should have default from "from@example.com"

  Scenario: ApplicationMailer has mailer layout
    Given I have an ApplicationMailer instance
    When I check the layout
    Then it should have layout "mailer"

  Scenario: ApplicationMailer can be subclassed
    When I create a test mailer that inherits from ApplicationMailer
    Then the test mailer should be a subclass of ApplicationMailer
    And the test mailer should be a subclass of ActionMailer::Base
    And the test mailer should inherit the default from address
    And the test mailer should inherit the mailer layout

  Scenario: ApplicationMailer can send emails
    When I create a test mailer that inherits from ApplicationMailer
    And I call a mail method on the test mailer
    Then it should return a mail object
    And the mail object should have the default from address

