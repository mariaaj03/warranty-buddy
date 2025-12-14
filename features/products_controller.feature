Feature: Products Controller
  As a user
  I want to export my warranties
  So I can use them in calendar applications

  Background:
    Given I am a signed in user
    And I have warranties in the system

  Scenario: User exports warranties to iCal calendar
    When I export warranties to iCal
    Then I should receive an iCal file

  Scenario: User exports warranties to iCal with reminders
    Given I have products with warranty expirations
    When I visit the calendar export URL with reminders "7,30"
    Then I should receive an iCal file
    And the calendar should contain events with alarms
    And the calendar should contain alarm triggers with timezone

  Scenario: User exports to Google Calendar successfully with no errors
    Given I have a Gmail connected user
    And I have products with warranty expirations
    And the calendar export will succeed with no errors
    When I export warranties to Google Calendar
    Then I should be redirected to dashboard

  Scenario: User exports to Google Calendar successfully with some errors
    Given I have a Gmail connected user
    And I have products with warranty expirations
    And the calendar export will succeed with errors
    When I export warranties to Google Calendar
    Then I should be redirected to dashboard

  Scenario: User exports to Google Calendar but export fails
    Given I have a Gmail connected user
    And I have products with warranty expirations
    And the calendar export will fail
    When I export warranties to Google Calendar
    Then I should be redirected to dashboard

  Scenario: User exports to iCal with reminders as non-array parameter
    Given I have products with warranty expirations
    When I visit the calendar export URL with reminders as non-array "7,30"
    Then I should receive an iCal file
