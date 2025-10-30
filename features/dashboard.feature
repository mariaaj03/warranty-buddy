Feature: Warranty Buddy Dashboard
  As a user
  I want to manage my product warranties
  So I can track purchase dates, warranty periods, and never lose track of important product information

  Background:
    Given the app is running
    And I am on the dashboard

  Scenario: View empty dashboard on first visit
    When I visit the homepage
    Then I should see "Warranty Buddy  -  Iteration 1"
    And I should see "Your Digital Memory for Every Purchase"
    And I should see "Not Connected" status for Gmail
    And I should see a "Connect Gmail" button
    And I should see "Add a product warranty" section
    And the warranties table should be empty

  Scenario: Connect Gmail account
    When I click "Connect Gmail"
    Then I should be redirected to Google OAuth
    And I should be redirected back to the dashboard
    And I should see "Gmail connected successfully!"
    And I should see "Connected" status for Gmail
    And I should see a "Disconnect Gmail" button

  Scenario: Disconnect Gmail account
    Given I have connected my Gmail account
    When I click "Disconnect Gmail"
    Then I should see "Gmail disconnected."
    And I should see "Not Connected" status for Gmail
    And I should see a "Connect Gmail" button

  Scenario: Add a new product warranty
    Given I am logged in with Gmail
    When I expand "Add a product warranty" section
    And I fill in "Product" with "MacBook Pro"
    And I fill in "Merchant" with "Apple Store"
    And I set "Purchase Date" to "2024-01-15"
    And I set "Warranty Length" to "12"
    And I click "Add warranty"
    Then I should see "Uploaded MacBook Pro"
    And I should see "MacBook Pro" in the warranties table
    And I should see "Apple Store" in the warranties table
    And I should see "2024-01-15" in the warranties table
    And I should see "12" months warranty
    And I should see "2025-01-15" as expiry date
    And I should see "Active" status

  Scenario: Add product with default values
    Given I am logged in with Gmail
    When I expand "Add a product warranty" section
    And I fill in "Product" with "iPhone 15"
    And I click "Add warranty"
    Then I should see "Uploaded iPhone 15"
    And I should see "iPhone 15" in the warranties table
    And I should see "Amazon" as merchant
    And I should see today's date as purchase date
    And I should see "12" months warranty
    And I should see "Active" status

  Scenario: Add product with invalid data
    When I expand "Add a product warranty" section
    And I leave "Product" empty
    And I click "Add warranty"
    Then I should see "Missing product"
    And the warranties table should be empty

  Scenario: View multiple warranties
    Given I have added a warranty for "MacBook Pro" from "Apple Store"
    And I have added a warranty for "iPhone 15" from "Amazon"
    When I visit the homepage
    Then I should see "MacBook Pro" in the warranties table
    And I should see "iPhone 15" in the warranties table
    And I should see 2 products in the warranties table

  Scenario: View expired warranty
    Given I have added a warranty for "Old Laptop" with purchase date "2020-01-01" and warranty "12" months
    When I visit the homepage
    Then I should see "Old Laptop" in the warranties table
    And I should see "Expired" status

  Scenario: Reset all data
    Given I have added a warranty for "Test Product"
    When I click "Reset" button
    Then I should see "OK" response
    And the warranties table should be empty
    And my Gmail should be disconnected

  Scenario: View API health
    When I visit "/dashboard/api_health"
    Then I should see JSON response with "ok" true
    And I should see "gmail_connected" status

  Scenario: View warranties API
    Given I have added a warranty for "API Test Product"
    When I visit "/dashboard/api_warranties"
    Then I should see JSON response with warranty data
    And I should see "API Test Product" in the response