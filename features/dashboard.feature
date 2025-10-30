Feature: Warranty Buddy Dashboard
  As a user
  I want to manage my product warranties
  So I can track purchase dates, warranty periods, and never lose track of important product information

  Background:
    Given the app is running
    And I am on the dashboard

  # USER STORY 1: First-time user experience
  Scenario: User views empty dashboard on first visit
    As a new user
    I want to see an empty dashboard with clear instructions
    So I understand how to get started
    When I visit the homepage
    Then I should see "Warranty Buddy - Iteration 1"
    And I should see "Your Digital Memory for Every Purchase"
    And I should see "Not Connected" status for Gmail
    And I should see a "Connect Gmail" button
    And I should see "Add a product warranty" section
    And the warranties table should be empty
    And I should see "No warranties yet." message

  # USER STORY 2: Gmail OAuth connection
  Scenario: User connects Gmail account
    As a user
    I want to connect my Gmail account
    So that I can automatically parse warranty information from my receipts
    When I click "Connect Gmail"
    Then I should be redirected to Google OAuth
    When I successfully authenticate with Google
    Then I should be redirected back to the dashboard
    And I should see "Connected" status for Gmail
    And I should see a "Disconnect Gmail" button
    And I should see a "Parse Gmail Receipts" button

  # USER STORY 3: Gmail disconnection
  Scenario: User disconnects Gmail account
    As a user
    I want to disconnect my Gmail account
    So that I can manage my privacy or switch accounts
    Given I have connected my Gmail account
    When I click "Disconnect Gmail"
    Then I should see "Not Connected" status for Gmail
    And I should see a "Connect Gmail" button
    And I should not see "Parse Gmail Receipts" button
    And I should not see any warranties in the table

  # USER STORY 4: Manual warranty entry - complete form
  Scenario: User manually adds a complete warranty entry
    As a user
    I want to manually add a warranty with all details
    So I can track purchases from any merchant
    Given I have connected my Gmail account
    When I expand "Add a product warranty" section
    And I fill in "Product" with "MacBook Pro"
    And I fill in "Merchant" with "Apple Store"
    And I set "Purchase Date" to "2024-01-15"
    And I set "Warranty Length" to "24"
    And I click "Add warranty"
    Then I should see "MacBook Pro" in the warranties table
    And I should see "Apple Store" in the warranties table
    And I should see "2024-01-15" in the warranties table
    And I should see "24" months warranty
    And I should see "2026-01-15" as expiry date
    And I should see "Active" status

  # USER STORY 5: Manual warranty entry - minimal form
  Scenario: User adds warranty with only product name
    As a user
    I want to quickly add a warranty with minimal information
    So I can track products without needing all details upfront
    Given I have connected my Gmail account
    When I expand "Add a product warranty" section
    And I fill in "Product" with "iPhone 15"
    And I leave "Merchant" empty
    And I click "Add warranty"
    Then I should see "iPhone 15" in the warranties table
    And I should see today's date as purchase date
    And I should see "12" months warranty as default
    And I should see "Active" status
    And I should see an empty merchant field

  # USER STORY 6: Manual warranty entry - validation
  Scenario: User attempts to add warranty without product name
    As a user
    I want validation when adding warranties
    So I don't create incomplete records
    Given I have connected my Gmail account
    When I expand "Add a product warranty" section
    And I leave "Product" empty
    And I fill in "Merchant" with "Amazon"
    And I click "Add warranty"
    Then the warranty should not be created
    And the warranties table should remain empty

  # USER STORY 7: Viewing multiple warranties
  Scenario: User views multiple warranty entries
    As a user
    I want to see all my warranties in one table
    So I can easily review what I own
    Given I have connected my Gmail account
    And I have added a warranty for "MacBook Pro" from "Apple Store"
    And I have added a warranty for "iPhone 15" from "Amazon"
    And I have added a warranty for "Samsung TV" from "Best Buy"
    When I visit the homepage
    Then I should see "MacBook Pro" in the warranties table
    And I should see "iPhone 15" in the warranties table
    And I should see "Samsung TV" in the warranties table
    And I should see 3 products in the warranties table

  # USER STORY 8: Warranty status indicators
  Scenario: User sees active warranty status
    As a user
    I want to see which warranties are still active
    So I know what's still covered
    Given I have connected my Gmail account
    And I have added a warranty for "New Laptop" with purchase date "2025-01-01" and warranty "12" months
    When I visit the homepage
    Then I should see "New Laptop" in the warranties table
    And I should see "Active" status with green badge

  # USER STORY 9: Expired warranty status
  Scenario: User sees expired warranty status
    As a user
    I want to see which warranties have expired
    So I know what's no longer covered
    Given I have connected my Gmail account
    And I have added a warranty for "Old Laptop" with purchase date "2020-01-01" and warranty "12" months
    When I visit the homepage
    Then I should see "Old Laptop" in the warranties table
    And I should see "Expired" status with red badge

  # USER STORY 10: Estimate indicator for parsed warranties
  Scenario: User sees estimate indicator for default warranties
    As a user
    I want to see when warranty length is estimated
    So I know the information may need verification
    Given I have connected my Gmail account
    And I have added a parsed warranty for "Parsed Product" with default 12 months warranty
    When I visit the homepage
    Then I should see "12" months warranty with "~" estimate indicator

  # USER STORY 11: Edit warranty entry
  @javascript
  Scenario: User edits warranty information
    As a user
    I want to edit warranty details
    So I can correct parsing errors or update information
    Given I have connected my Gmail account
    And I have added a warranty for "MacBook Pro" from "Apple"
    When I visit the homepage
    And I click the edit button for "MacBook Pro"
    Then I should see an edit modal
    When I change "Product Name" to "MacBook Pro M2"
    And I change "Merchant" to "Apple Store"
    And I change "Purchase Date" to "2024-02-01"
    And I change "Warranty Length" to "36"
    And I click "Save Changes"
    Then I should see "MacBook Pro M2" in the warranties table
    And I should see "Apple Store" in the warranties table
    And I should see "2024-02-01" in the warranties table
    And I should see "36" months warranty

  # USER STORY 12: Delete warranty entry
  @javascript
  Scenario: User deletes a warranty entry
    As a user
    I want to delete warranty entries
    So I can remove items I no longer own or track
    Given I have connected my Gmail account
    And I have added a warranty for "Old Product" from "Old Store"
    And I have added a warranty for "New Product" from "New Store"
    When I visit the homepage
    And I click the delete button for "Old Product"
    Then "Old Product" should be removed from the table
    And I should still see "New Product" in the warranties table
    And I should see 1 product in the warranties table

  # USER STORY 13: Search warranties
  Scenario: User searches warranties by product name
    As a user
    I want to search my warranties by product name
    So I can quickly find specific items
    Given I have connected my Gmail account
    And I have added a warranty for "MacBook Pro" from "Apple"
    And I have added a warranty for "iPhone 15" from "Apple"
    When I visit the homepage
    And I fill in search field with "MacBook"
    And I click "Apply"
    Then I should see "MacBook Pro" in the warranties table
    And I should not see "iPhone 15" in the warranties table

  # USER STORY 14: Search by merchant
  Scenario: User searches warranties by merchant
    As a user
    I want to search my warranties by merchant
    So I can see all purchases from a specific store
    Given I have connected my Gmail account
    And I have added a warranty for "Product A" from "Amazon"
    And I have added a warranty for "Product B" from "Best Buy"
    When I visit the homepage
    And I fill in search field with "Amazon"
    And I click "Apply"
    Then I should see "Product A" in the warranties table
    And I should not see "Product B" in the warranties table

  # USER STORY 15: Filter by active status
  Scenario: User filters warranties to show only active
    As a user
    I want to filter warranties by status
    So I can focus on what's currently covered
    Given I have connected my Gmail account
    And I have added a warranty for "Active Product" with purchase date "2025-01-01" and warranty "12" months
    And I have added a warranty for "Expired Product" with purchase date "2020-01-01" and warranty "12" months
    When I visit the homepage
    And I select "Active" from status filter
    And I click "Apply"
    Then I should see "Active Product" in the warranties table
    And I should not see "Expired Product" in the warranties table

  # USER STORY 16: Filter by expired status
  Scenario: User filters warranties to show only expired
    As a user
    I want to see expired warranties
    So I know what's no longer covered
    Given I have connected my Gmail account
    And I have added a warranty for "Active Product" with purchase date "2025-01-01" and warranty "12" months
    And I have added a warranty for "Expired Product" with purchase date "2020-01-01" and warranty "12" months
    When I visit the homepage
    And I select "Expired" from status filter
    And I click "Apply"
    Then I should see "Expired Product" in the warranties table
    And I should not see "Active Product" in the warranties table

  # USER STORY 17: Filter by expiring soon
  Scenario: User filters warranties expiring soon
    As a user
    I want to see warranties expiring within 30 days
    So I can plan ahead
    Given I have connected my Gmail account
    And I have added a warranty expiring in 15 days
    And I have added a warranty expiring in 60 days
    When I visit the homepage
    And I select "Expiring Soon" from status filter
    And I click "Apply"
    Then I should see the warranty expiring in 15 days
    And I should not see the warranty expiring in 60 days

  # USER STORY 18: Filter by merchant
  Scenario: User filters warranties by merchant
    As a user
    I want to filter warranties by merchant
    So I can see all purchases from a specific store
    Given I have connected my Gmail account
    And I have added a warranty for "Product A" from "Amazon"
    And I have added a warranty for "Product B" from "Best Buy"
    And I have added a warranty for "Product C" from "Amazon"
    When I visit the homepage
    And I select "Amazon" from merchant filter
    And I click "Apply"
    Then I should see "Product A" in the warranties table
    And I should see "Product C" in the warranties table
    And I should not see "Product B" in the warranties table

  # USER STORY 19: Sort by expiry date
  Scenario: User sorts warranties by expiry date
    As a user
    I want to sort warranties by expiry date
    So I can see what expires soonest first
    Given I have connected my Gmail account
    And I have added a warranty expiring on "2025-06-01"
    And I have added a warranty expiring on "2025-01-01"
    When I visit the homepage
    And I select "Expiry Date" from sort dropdown
    And I click "Apply"
    Then I should see warranties sorted by expiry date ascending

  # USER STORY 20: Sort by product name
  Scenario: User sorts warranties by product name
    As a user
    I want to sort warranties alphabetically by product name
    So I can find items easily
    Given I have connected my Gmail account
    And I have added a warranty for "Zebra Product" from "Store"
    And I have added a warranty for "Apple Product" from "Store"
    When I visit the homepage
    And I select "Product Name" from sort dropdown
    And I click "Apply"
    Then I should see "Apple Product" before "Zebra Product"

  # USER STORY 21: Sort by purchase date
  Scenario: User sorts warranties by purchase date
    As a user
    I want to sort warranties by purchase date
    So I can see my recent purchases first
    Given I have connected my Gmail account
    And I have added a warranty purchased on "2024-01-01"
    And I have added a warranty purchased on "2024-03-01"
    When I visit the homepage
    And I select "Purchase Date" from sort dropdown
    And I click "Apply"
    Then I should see warranties sorted by purchase date

  # USER STORY 22: Sort by merchant
  Scenario: User sorts warranties by merchant
    As a user
    I want to sort warranties by merchant name
    So I can group purchases by store
    Given I have connected my Gmail account
    And I have added a warranty for "Product A" from "Zebra Store"
    And I have added a warranty for "Product B" from "Apple Store"
    When I visit the homepage
    And I select "Merchant" from sort dropdown
    And I click "Apply"
    Then I should see "Apple Store" before "Zebra Store"

  # USER STORY 23: Parse Gmail receipts
  Scenario: User parses Gmail receipts for warranties
    As a user
    I want to automatically extract warranty information from Gmail receipts
    So I don't have to manually enter each purchase
    Given I have connected my Gmail account
    When I click "Parse Gmail Receipts"
    Then the system should fetch emails from Gmail
    And the system should parse receipt emails
    And new warranty entries should be created from parsed receipts
    And I should be redirected to the dashboard

  # USER STORY 24: Export warranties to CSV
  Scenario: User exports warranties to CSV
    As a user
    I want to export my warranties to CSV
    So I can back them up or use them elsewhere
    Given I have connected my Gmail account
    And I have added a warranty for "Product A" from "Store A"
    And I have added a warranty for "Product B" from "Store B"
    When I click "Export CSV"
    Then I should download a CSV file
    And the CSV should contain "Product A"
    And the CSV should contain "Product B"

  # USER STORY 25: Export warranties to iCal
  Scenario: User exports warranties to iCal
    As a user
    I want to export warranty expiration dates to my calendar
    So I get reminders before warranties expire
    Given I have connected my Gmail account
    And I have added a warranty for "Product A" expiring on "2025-06-15"
    When I click "Export iCal"
    Then I should download an iCal file
    And the iCal should contain expiration date "2025-06-15"

  # USER STORY 26: Reset filters and search
  Scenario: User resets filters and search
    As a user
    I want to reset my filters and search
    So I can start fresh with all warranties visible
    Given I have connected my Gmail account
    And I have applied search and filters
    When I click "Reset"
    Then all filters should be cleared
    And search should be cleared
    And I should see all warranties in the table

  # USER STORY 27: API health check
  Scenario: Developer checks API health status
    As a developer
    I want to check the API health status
    So I can verify the service is running
    When I visit "/dashboard/api_health"
    Then I should see JSON response with "ok" true
    And I should see "gmail_connected" status in response

  # USER STORY 28: API warranties endpoint
  Scenario: Developer fetches warranties via API
    As a developer
    I want to fetch warranties via API
    So I can integrate with other services
    Given I have connected my Gmail account
    And I have added a warranty for "API Test Product" from "Test Store"
    When I visit "/dashboard/api_warranties"
    Then I should see JSON response with warranty data
    And I should see "API Test Product" in the response
    And I should see "Test Store" in the response

  # USER STORY 29: User cannot access warranties without Gmail connection
  Scenario: User tries to add warranty without Gmail connection
    As a user
    I want appropriate restrictions when not connected
    So I understand what features require Gmail
    Given I have not connected my Gmail account
    When I expand "Add a product warranty" section
    And I fill in "Product" with "Test Product"
    And I click "Add warranty"
    Then I should see an error message about connecting Gmail first
    And the warranty should not be created

  # USER STORY 30: Comprehensive warranty management flow
  Scenario: User completes full warranty management workflow
    As a user
    I want to complete a full workflow of managing warranties
    So I understand all features work together
    Given I visit the homepage
    When I connect my Gmail account
    And I parse Gmail receipts
    And I manually add a warranty for "Manual Product" from "Manual Store"
    And I edit the "Manual Product" warranty to change merchant to "Updated Store"
    And I search for "Manual"
    And I filter by "Active" status
    And I sort by "Product Name"
    And I delete a warranty entry
    And I export to CSV
    Then I should have successfully used all major features
    And the dashboard should reflect my changes
