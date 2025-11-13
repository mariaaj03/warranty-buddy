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
    And the Calendar API is unavailable
    When I export warranties to calendar
    Then it should return failure status
    And it should include error message
    And it should log the calendar error

  # Additional coverage scenarios
  Scenario: Service skips products without expiry date
    Given I have an authenticated calendar service
    And I have products with and without expiry dates
    When I export warranties to calendar
    Then it should only create events for products with expiry dates
    And it should skip products without expiry dates

  Scenario: Service handles insufficient authentication scopes error
    Given I have an authenticated calendar service
    And the Calendar API will raise insufficient scopes error
    When I export warranties to calendar
    Then it should return a user-friendly error message
    And it should log the error with backtrace

  Scenario: Service builds description with all product fields
    Given I have an authenticated calendar service
    And I have a product with all fields populated
    When I export warranties to calendar
    Then the event description should include all product information

  Scenario: Service builds description with minimal product fields
    Given I have an authenticated calendar service
    And I have a product with only product name
    When I export warranties to calendar
    Then the event description should include only product name

  Scenario: Service creates reminder with zero days
    Given I have an authenticated calendar service
    And I have products with warranty expirations
    When I export warranties to calendar with reminder days "0, 7"
    Then it should create reminders with correct minutes
    And the zero day reminder should have 0 minutes