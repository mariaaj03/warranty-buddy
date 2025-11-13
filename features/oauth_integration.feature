Feature: Google OAuth Integration
  As a user
  I want to authenticate with Google
  So that I can access my Gmail data and manage warranties

  Background:
    Given the app is running
    And I am on the dashboard

  Scenario: Successful Google OAuth login
    As a user
    I want to successfully authenticate with Google
    So that I can access my Gmail data
    Given I have not connected my Gmail account
    When I click "Connect Gmail"
    Then I should be redirected to Google OAuth
    When I successfully authenticate with Google
    Then I should be redirected back to the dashboard
    And I should see "Connected" status for Gmail
    And I should see a "Disconnect Gmail" button
    And I should see a "Parse Gmail Receipts" button

  Scenario: User denies Google OAuth access
    As a user
    I want to be able to deny Google access
    So that I can maintain my privacy
    Given I have not connected my Gmail account
    When I click "Connect Gmail"
    Then I should be redirected to Google OAuth
    When I deny access to the application
    Then I should be redirected back to the dashboard
    And I should see "Not Connected" status for Gmail
    And I should see a "Connect Gmail" button
    And I should not see "Parse Gmail Receipts" button

  Scenario: OAuth token expires and needs refresh
    As a user
    I want my session to be maintained when tokens refresh
    So that I don't have to re-authenticate frequently
    Given I have connected my Gmail account
    And my OAuth token has expired
    When I visit the dashboard
    Then my session should be automatically refreshed
    And I should still see "Connected" status for Gmail

  Scenario: OAuth service is unavailable
    As a user
    I want to be informed when OAuth service is down
    So that I understand why authentication failed
    Given I have not connected my Gmail account
    And Google OAuth service is unavailable
    When I click "Connect Gmail"
    Then I should see an error message about OAuth service
    And I should remain on the dashboard

  Scenario: User disconnects Gmail account
    As a user
    I want to disconnect my Gmail account
    So that I can revoke access when needed
    Given I have connected my Gmail account
    When I click "Disconnect Gmail" for OAuth
    Then I should see "Not Connected" status for Gmail
    And I should see a "Connect Gmail" button
    And I should not see "Parse Gmail Receipts" button
    And my Gmail data should be cleared from the session

  Scenario: OAuth callback raises an exception
    As a user
    I want to be handled gracefully when OAuth callback fails
    So that I can retry authentication
    Given the OAuth callback will raise an exception
    When I visit the OAuth callback URL
    Then I should be redirected to the root path
    And I should see an alert message "Authentication failed. Please try again."
    And it should log an OAuth error
