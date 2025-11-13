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

  # USER STORY 67: Warranty Export to Calendar
  Scenario: Service exports single warranty to calendar successfully
    Given I have an authenticated calendar service
    And I have a product with warranty expiration
    When I export warranties to calendar
    Then it should create a calendar event
    And the event should be on the warranty expiration date
    And the event should have warranty details in description
    And it should return success status

  Scenario: Service exports multiple warranties to calendar
    Given I have an authenticated calendar service
    And I have multiple products with different expiry dates
    When I export warranties to calendar
    Then it should create multiple calendar events
    And each event should have correct expiration date
    And it should return count of created events

  Scenario: Service skips products without expiry dates
    Given I have an authenticated calendar service
    And I have products with and without expiry dates
    When I export warranties to calendar
    Then it should only create events for products with expiry dates
    And it should skip products without expiry dates
    And it should return correct count

  # USER STORY 68: Calendar Event Creation
  Scenario: Service creates detailed calendar events
    Given I have an authenticated calendar service
    And I have a product "iPhone 15 Pro" from "Apple" expiring on "2025-01-15"
    When I export this warranty to calendar
    Then the calendar event should have title "Warranty expires: iPhone 15 Pro"
    And the description should include product name
    And the description should include merchant name
    And the description should include purchase date
    And the description should include warranty length

  Scenario: Service sets correct event dates and times
    Given I have an authenticated calendar service
    And I have a product expiring on "2025-06-15"
    When I export this warranty to calendar
    Then the event should start on "2025-06-15"
    And the event should end on "2025-06-16"
    And the event should be an all-day event
    And the timezone should be "America/New_York"

  # USER STORY 69: Email Reminders
  Scenario: Service adds email reminders to calendar events
    Given I have an authenticated calendar service
    And I have a product with warranty expiration
    When I export warranties with reminder days [7, 30]
    Then the calendar event should have email reminder 7 days before
    And the calendar event should have email reminder 30 days before
    And the reminders should use email notification method

  Scenario: Service handles same-day reminders
    Given I have an authenticated calendar service  
    And I have a product with warranty expiration
    When I export warranties with reminder days [0]
    Then the calendar event should have reminder on the same day
    And the reminder should be set for 0 minutes

  Scenario: Service creates events without reminders when none specified
    Given I have an authenticated calendar service
    And I have a product with warranty expiration
    When I export warranties with no reminders
    Then the calendar event should be created successfully
    And the event should not have custom reminders

  # USER STORY 70: Error Handling
  Scenario: Service handles insufficient calendar permissions
    Given I have a user with Gmail but no calendar permissions
    When I initialize the calendar service
    And I export warranties to calendar
    Then it should return permission error
    And it should suggest re-authentication
    And it should not create any events

  Scenario: Service handles individual event creation failures
    Given I have an authenticated calendar service
    And I have multiple products with warranty expirations
    And one product causes calendar API error
    When I export warranties to calendar
    Then it should create events for successful products
    And it should collect errors for failed products
    And it should return partial success status

  Scenario: Service handles complete calendar API failure
    Given I have an authenticated calendar service
    And the Calendar API is unavailable
    When I export warranties to calendar
    Then it should return failure status
    And it should include error message
    And it should log the error

  # USER STORY 71: Token Management
  Scenario: Service handles token refresh during operation
    Given I have a user with nearly expired calendar token
    When I initialize the calendar service
    And I export warranties to calendar
    Then it should refresh the token automatically
    And it should complete the export successfully
    And it should update the user's stored tokens

  Scenario: Service handles refresh token failure
    Given I have a user with invalid refresh token
    When I initialize the calendar service
    Then it should handle the refresh failure
    And it should not authenticate
    And exports should return authentication error

  # USER STORY 72: Data Validation and Edge Cases
  Scenario: Service validates product data before export
    Given I have an authenticated calendar service
    And I have a product with missing required fields
    When I export warranties to calendar
    Then it should skip products with missing expiry dates
    And it should not create events for invalid products
    And it should continue processing valid products

  Scenario: Service handles very long product names
    Given I have an authenticated calendar service
    And I have a product with very long name "This is a very long product name that exceeds normal limits and should be handled gracefully by the calendar service without breaking"
    When I export this warranty to calendar
    Then it should create the event successfully
    And the event title should be properly formatted
    And the description should include the full name

  # USER STORY 73: Calendar Service Integration
  Scenario: Service integrates with user's primary calendar
    Given I have an authenticated calendar service
    When I export warranties to calendar
    Then it should use the user's primary calendar
    And events should appear in the default calendar

  Scenario: Service logs successful operations
    Given I have an authenticated calendar service
    And I have products with warranty expirations
    When I export warranties to calendar
    Then it should log successful event creation
    And it should include event IDs in logs
    And it should log the product names

  Scenario: Service provides detailed error information
    Given I have an authenticated calendar service
    And some products will fail to export
    When I export warranties to calendar
    Then the response should include specific error messages
    And each error should identify the problematic product
    And the response should indicate partial vs complete failure