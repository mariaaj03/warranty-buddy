Feature: Products Controller
  As a user
  I want to export my warranties to calendars
  So that I can track warranty expirations

  Background:
    Given I have a signed in user for products controller

  # Calendar export (iCal format)
  Scenario: User exports warranties to iCal calendar
    Given I have products with expiry dates
    When I visit the calendar export URL
    Then I should receive an iCal file
    And the calendar should contain warranty events

  Scenario: User exports warranties with reminder days
    Given I have products with expiry dates
    When I visit the calendar export URL with reminders "7,30"
    Then I should receive an iCal file
    And the calendar should contain events with alarms

  Scenario: System filters invalid reminder days
    Given I have products with expiry dates
    When I visit the calendar export URL with reminders "7,abc,-5,30"
    Then I should receive an iCal file
    And invalid reminder days should be filtered out

  Scenario: System skips products without expiry dates in calendar export
    Given I have products with and without expiry dates
    When I visit the calendar export URL
    Then I should receive an iCal file
    And only products with expiry dates should be included

  # Google Calendar export
  Scenario: User exports warranties to Google Calendar successfully
    Given I have a Gmail connected user
    And I have products with expiry dates
    When I export warranties to Google Calendar
    Then I should be redirected to dashboard
    And I should see a success message

  Scenario: User exports warranties to Google Calendar with errors
    Given I have a Gmail connected user
    And I have products with warranty expirations
    And some products will fail to export
    When I export warranties to Google Calendar
    Then I should be redirected to dashboard
    And I should see a partial success message with errors

  Scenario: User tries to export without Gmail connection
    Given I have a user without Gmail connection
    And I have products with expiry dates
    When I export warranties to Google Calendar
    Then I should be redirected to dashboard
    And I should see an alert "Please connect your Google account first"

  Scenario: User tries to export with no products having expiry dates
    Given I have a Gmail connected user
    And I have products without expiry dates
    When I export warranties to Google Calendar
    Then I should be redirected to dashboard
    And I should see an alert "No warranties with expiry dates found"

  Scenario: Google Calendar export fails completely
    Given I have a Gmail connected user
    And I have products with expiry dates
    And the Calendar API is unavailable
    When I export warranties to Google Calendar
    Then I should be redirected to dashboard
    And I should see an error message

  Scenario: System filters reminder days in Google Calendar export
    Given I have a Gmail connected user
    And I have products with expiry dates
    When I export warranties to Google Calendar with reminders "7,abc,-5,30,0"
    Then invalid reminder days should be filtered out
    And only valid non-negative reminder days should be used

  Scenario: System creates calendar alarms with reminder days
    Given I have products with expiry dates
    When I visit the calendar export URL with reminders "7,30"
    Then I should receive an iCal file
    And the calendar should contain alarm triggers with timezone

  Scenario: System redirects when no products have expiry dates for Google Calendar
    Given I have a Gmail connected user
    And I have products without expiry dates
    When I export warranties to Google Calendar
    Then I should be redirected to dashboard
    And I should see an alert "No warranties with expiry dates found"

  Scenario: System shows success message when export succeeds with no errors
    Given I have a Gmail connected user
    And I have products with expiry dates
    And the calendar export will succeed with no errors
    When I export warranties to Google Calendar
    Then I should be redirected to dashboard
    And I should see a success message "Successfully exported"

  Scenario: System shows partial success message when export has errors
    Given I have a Gmail connected user
    And I have products with expiry dates
    And the calendar export will succeed with errors
    When I export warranties to Google Calendar
    Then I should be redirected to dashboard
    And I should see a partial success message with error count

  Scenario: System shows error message when export fails
    Given I have a Gmail connected user
    And I have products with expiry dates
    And the calendar export will fail
    When I export warranties to Google Calendar
    Then I should be redirected to dashboard
    And I should see an error message "Failed to export to Google Calendar"

