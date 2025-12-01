# features/google_calendar.feature
Feature: Google Calendar Integration
  As a user
  I want to export my warranties to Google Calendar
  So I get reminders before my warranties expire

  Background:
    Given the Google Calendar service is available

  # USER STORY 66: Calendar Authentication
  Scenario: Service authenticates with valid user credentials
    Given I have a user with valid calendar credentials
    When I initialize the calendar service
    Then it should authenticate with Google Calendar
    And it should be ready to create events

  Scenario: Service handles missing credentials gracefully
    Given I have a user without calendar credentials
    When I initialize the calendar service
    Then it should handle missing credentials
    And the service should not be authenticated

  Scenario: Service refreshes expired calendar tokens
    Given I have a user with expired calendar token
    When I initialize the calendar service
    Then it should refresh the calendar token
    And it should update the user credentials

  # USER STORY 70: Error Handling
  Scenario: Service handles insufficient calendar permissions
    Given I have a user with Gmail but no calendar permissions
    When I initialize the calendar service
    And I export warranties to calendar
    Then it should return permission error
    And it should suggest re-authentication
    And it should not create any events

  Scenario: Service handles complete calendar API failure
    Given I have an authenticated calendar service
    And the Calendar API is unavailable for calendar service
    When I export warranties to calendar
    Then it should return failure status
    And it should include error message
    And it should log the calendar error

  # Coverage scenarios for export_warranties method
  Scenario: Service successfully creates calendar events for products with expiry dates
    Given I have an authenticated calendar service
    And I have products with expiry dates for export
    And the Calendar API will successfully create events
    When I export warranties to calendar
    Then events should be created successfully
    And the service should log successful event creation

  Scenario: Service skips products without expiry dates
    Given I have an authenticated calendar service
    And I have products with and without expiry dates for calendar export
    And the Calendar API will successfully create events
    When I export warranties to calendar
    Then only products with expiry dates should have events created

  Scenario: Service handles errors when creating individual events
    Given I have an authenticated calendar service
    And I have products with expiry dates for export
    And the Calendar API will fail for some events
    When I export warranties to calendar
    Then the export should succeed with partial errors
    And errors should be collected for failed products

  Scenario: Service handles insufficient authentication scopes error
    Given I have an authenticated calendar service
    And I have products with expiry dates for export
    And the Calendar API will raise insufficient scopes error
    When I export warranties to calendar
    Then the error message should indicate calendar permissions issue
    And the service should log the error with backtrace

  Scenario: Service handles generic errors when creating events
    Given I have an authenticated calendar service
    And I have products with expiry dates for export
    And the Calendar API will raise a generic error
    When I export warranties to calendar
    Then the error message should be the original error message
    And the service should log the error with backtrace