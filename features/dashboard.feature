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
    Given I have connected my Gmail account
    When I visit the homepage
    Then I should see "Warranty Buddy"
    And I should see "Your Digital Memory for Every Purchase"
    And I should see "Connected" status for Gmail
    And I should see "Add a product warranty" section
    And the warranties table should be empty
    And I should see "No warranties yet." message

  # USER STORY 2: Gmail OAuth connection

Scenario: User connects Gmail account
  As a user
  I want to connect my Gmail account
  So that I can automatically parse warranty information from my receipts
  Given I have not connected my Gmail account    
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

  # USER STORY 11: Delete warranty entry
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

  # USER STORY 12: Search warranties
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

  # USER STORY 13: Search by merchant
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

  # USER STORY 14: Filter by expiring soon
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

  # USER STORY 15: Filter by merchant
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

  # USER STORY 16: Sort by expiry date
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

  # USER STORY 17: Sort by product name
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

  # USER STORY 18: Sort by purchase date
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

  # USER STORY 19: Sort by merchant
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

  # USER STORY 20: Parse Gmail receipts
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

  # USER STORY 21: Export warranties to CSV
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

  # USER STORY 22: Export warranties to iCal
  Scenario: User exports warranties to iCal
    As a user
    I want to export warranty expiration dates to my calendar
    So I get reminders before warranties expire
    Given I have connected my Gmail account
    And I have added a warranty for "Product A" expiring on "2025-06-15"
    When I click "Export iCal"
    Then I should download an iCal file
    And the iCal should contain expiration date "2025-06-15"

  # USER STORY 23: Reset filters and search
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

  # USER STORY 24: API health check
  Scenario: Developer checks API health status
    As a developer
    I want to check the API health status
    So I can verify the service is running
    When I visit "/dashboard/api_health"
    Then I should see JSON response with "ok" true
    And I should see "gmail_connected" status in response

  # USER STORY 25: API warranties endpoint
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

  # USER STORY 26: User must connect Gmail to access dashboard
Scenario: User tries to add warranty without Gmail connection
  As a user
  I want to be redirected to connect Gmail if I try to access dashboard without connection
  So I understand I need to connect Gmail first
  Given I have not connected my Gmail account
  When I visit the homepage
  Then I should be redirected to connect Gmail
  And I should not see the dashboard



  # Coverage scenarios for upload method
  Scenario: User uploads PDF receipt file
    Given I am a signed in user
    And I have a receipt processor that processes PDF successfully
    When I upload a PDF receipt file with product name
    Then the receipt should be processed as PDF
    And the warranty should be created

  Scenario: User uploads image receipt file
    Given I am a signed in user
    And I have a receipt processor that processes image successfully
    When I upload an image receipt file with product name
    Then the receipt should be processed as image
    And the warranty should be created

  # Coverage scenarios for missing lines
  Scenario: User filters dashboard by expired status
    Given I am a signed in user
    And I have products with various statuses
    When I visit the dashboard with status filter "expired"
    Then I should only see expired warranties


  Scenario: User filters dashboard by expiring soon status
    Given I am a signed in user
    And I have products with various statuses
    When I visit the dashboard with status filter "expiring_soon"
    Then I should see the dashboard

  Scenario: User searches dashboard with search term
    Given I am a signed in user
    And I have products with various statuses
    When I visit the dashboard with search "Active"
    Then I should see the dashboard

  Scenario: User filters dashboard by merchant
    Given I am a signed in user
    And I have products with various statuses
    When I visit the dashboard with merchant filter "Test Merchant"
    Then I should see the dashboard

  Scenario: User uploads warranty with receipt data that has line items
    Given I am a signed in user
    And I have a receipt processor that returns receipt data with line items
    When I upload a receipt file without product name
    Then the warranty should be created with product name from line items

  Scenario: User manually uploads warranty and AI lookup returns warranty info
    Given I am a signed in user
    And I have an AI service that returns warranty info
    When I manually upload a warranty for "iPhone 15" from "Apple" without warranty length
    Then the warranty should be created with AI warranty info

  Scenario: User manually uploads warranty and AI lookup returns nil
    Given I am a signed in user
    And I have an AI service that returns nil for warranty lookup
    When I manually upload a warranty for "iPhone 15" from "Apple" without warranty length
    Then the warranty should be created without AI warranty info

  Scenario: User manually uploads warranty and AI lookup raises an error
    Given I am a signed in user
    And I have an AI service that raises an error for warranty lookup
    When I manually upload a warranty for "iPhone 15" from "Apple" without warranty length
    Then the warranty should be created without AI warranty info

  # Coverage scenarios for check_warranty_eligibility
  Scenario: User checks warranty eligibility with issue description via JSON
    Given I am a signed in user
    And I have connected my Gmail account
    And I have a product with ID
    When I check warranty eligibility with issue description "screen cracked" via JSON
    Then I should receive warranty eligibility result in JSON format

  Scenario: User checks warranty eligibility with issue description via HTML
    Given I am a signed in user
    And I have connected my Gmail account
    And I have a product with ID
    When I check warranty eligibility with issue description "screen cracked" via HTML
    Then I should be redirected to dashboard with notice

  Scenario: User checks warranty eligibility for non-existent product
    Given I am a signed in user
    And I have connected my Gmail account
    When I check warranty eligibility for non-existent product via JSON
    Then I should receive a not found error in JSON format
