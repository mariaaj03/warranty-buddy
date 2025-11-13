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

  # USER STORY 26: User cannot access warranties without Gmail connection
Scenario: User tries to add warranty without Gmail connection
  As a user
  I want to be able to add warranties manually even without Gmail
  So I can track warranties from any source
  Given I have not connected my Gmail account
  When I expand "Add a product warranty" section
  And I fill in "Product" with "Test Product"
  And I click "Add warranty"
  Then I should see "Warranty added successfully!"
  And I should see "Test Product" in the warranties table

  # USER STORY 27: Comprehensive warranty management flow
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

  # Additional coverage scenarios
  Scenario: System updates warranty with valid product and purchase date
    Given I have a signed in user for dashboard controller
    And I have a product with id
    When I update the warranty with purchase date "2024-01-15"
    Then the warranty should be updated successfully

  Scenario: System returns not found when updating non-existent warranty
    Given I have a signed in user for dashboard controller
    When I update a non-existent warranty
    Then I should receive a not found response

  Scenario: System handles invalid purchase date format in update
    Given I have a signed in user for dashboard controller
    And I have a product with id
    When I update the warranty with invalid purchase date "invalid-date"
    Then I should receive a bad request response

  Scenario: System updates warranty without purchase date
    Given I have a signed in user for dashboard controller
    And I have a product with id
    When I update the warranty without purchase date
    Then the warranty should be updated successfully

  Scenario: System looks up warranty info and returns nil
    Given I have a signed in user for dashboard controller
    When I lookup warranty info for product "Unknown Product" from merchant "Unknown Merchant"
    And the AI service returns nil
    Then I should receive a JSON response with nil

  Scenario: System checks warranty eligibility with Gmail connected
    Given I have a signed in user with Gmail connected
    And I have a product
    When I check warranty eligibility with issue description "Screen is cracked"
    Then I should receive warranty eligibility result

  Scenario: System checks warranty eligibility without Gmail connection
    Given I have a signed in user without Gmail connection
    When I check warranty eligibility
    Then I should be redirected with an alert

  Scenario: System checks warranty eligibility with blank issue description
    Given I have a signed in user with Gmail connected
    And I have a product
    When I check warranty eligibility with blank issue description
    Then I should receive a bad request error

  Scenario: System checks warranty eligibility for non-existent product
    Given I have a signed in user with Gmail connected
    When I check warranty eligibility for non-existent product
    Then I should receive a not found error

  Scenario: System parses Gmail receipts with Gmail connected
    Given I have a signed in user with Gmail connected
    When I parse Gmail receipts
    Then receipts should be processed

  Scenario: System parses Gmail receipts and skips blank product names
    Given I have a signed in user with Gmail connected
    And I have Gmail receipts with blank product names
    When I parse Gmail receipts
    Then blank product names should be skipped

  Scenario: System parses Gmail receipts and skips existing products
    Given I have a signed in user with Gmail connected
    And I have an existing product with raw_email_id
    And I have Gmail receipts with matching raw_email_id
    When I parse Gmail receipts
    Then existing products should be skipped

  Scenario: System parses Gmail receipts and skips receipts with blank product name or purchase date
    Given I have a signed in user with Gmail connected
    And I have Gmail receipts with blank product name or purchase date
    When I parse Gmail receipts
    Then invalid receipts should be skipped

  Scenario: System handles Gmail API permission denied error
    Given I have a signed in user with Gmail connected
    And the Gmail service will raise a permission denied error
    When I parse Gmail receipts
    Then I should be redirected to dashboard

  Scenario: System handles generic Gmail parsing error
    Given I have a signed in user with Gmail connected
    And the Gmail service will raise a generic error
    When I parse Gmail receipts
    Then I should be redirected to dashboard

  Scenario: System uses AI warranty info when available in upload
    Given I have a signed in user for dashboard controller
    When I upload a manual warranty with merchant "Apple"
    And the AI service returns warranty info
    Then the warranty should use AI warranty months

  Scenario: System handles AI warranty lookup failure in upload
    Given I have a signed in user for dashboard controller
    When I upload a manual warranty with merchant "Apple"
    And the AI service raises an error
    Then the warranty should be created without AI data

  Scenario: System processes PDF receipt file upload
    Given I have a signed in user for dashboard controller
    When I upload a PDF receipt file
    Then the receipt should be processed as PDF

  Scenario: System processes image receipt file upload
    Given I have a signed in user for dashboard controller
    When I upload an image receipt file
    Then the receipt should be processed as image

  Scenario: System rejects unsupported file type
    Given I have a signed in user for dashboard controller
    When I upload an unsupported file type
    Then I should receive an error about unsupported file type

  Scenario: System handles receipt processing error
    Given I have a signed in user for dashboard controller
    And the receipt processor will raise an error
    When I upload a PDF receipt file
    Then I should receive an error about processing failure

  Scenario: System handles receipt data extraction failure with Vision API configured
    Given I have a signed in user for dashboard controller
    And the Vision API is configured
    When I upload a receipt file that fails to extract data
    Then I should receive an error about unclear image

  Scenario: System handles receipt data extraction failure without Vision API or OAuth
    Given I have a signed in user for dashboard controller
    And the Vision API is not configured
    And the user does not have OAuth credentials
    When I upload a receipt file that fails to extract data
    Then I should receive an error about Vision API configuration

  Scenario: System handles receipt data extraction failure with OAuth but no Vision API
    Given I have a signed in user with Gmail connected
    And the Vision API is not configured
    When I upload a receipt file that fails to extract data
    Then I should receive an error about unclear image

  Scenario: System uploads warranty without receipt file

  Scenario: System filters warranties by active status
    Given I have a signed in user for dashboard controller
    And I have products with various statuses
    When I visit the dashboard with status filter "active"
    Then I should only see active warranties

  Scenario: System filters warranties by expired status
    Given I have a signed in user for dashboard controller
    And I have products with various statuses
    When I visit the dashboard with status filter "expired"
    Then I should only see expired warranties

  Scenario: System extracts product name from receipt line items when product name is blank
    Given I have a signed in user for dashboard controller
    And I have a receipt processor that returns line items
    When I upload a receipt file with blank product name
    Then the product name should be extracted from line items

  Scenario: System extracts product name from receipt data when product name is blank
    Given I have a signed in user for dashboard controller
    And I have a receipt processor that returns product name
    When I upload a receipt file with blank product name
    Then the product name should be extracted from receipt data

  Scenario: System sets extraction error when receipt data is nil and no error occurred
    Given I have a signed in user for dashboard controller
    And I have a receipt processor that returns nil
    And Vision API is not configured
    And user has no OAuth credentials
    When I upload a receipt file
    Then I should see an extraction error about Vision API configuration

  Scenario: System sets extraction error when receipt data is nil and Vision API is configured
    Given I have a signed in user for dashboard controller
    And I have a receipt processor that returns nil
    And Vision API is configured
    When I upload a receipt file
    Then I should see an extraction error about unclear image

  Scenario: System sets flash alert when extraction error exists
    Given I have a signed in user for dashboard controller
    And I have a receipt processor that raises an error
    When I upload a receipt file
    Then the flash alert should contain the extraction error

  Scenario: System uses warranty length from receipt data when present
    Given I have a signed in user for dashboard controller
    And I have a receipt processor that returns warranty length
    When I upload a receipt file
    Then the warranty months should be set from receipt data

  Scenario: System sets warranty months to nil when converted value is zero
    Given I have a signed in user for dashboard controller
    And I have a receipt processor that returns zero warranty length
    When I upload a receipt file
    Then the warranty months should be nil

  Scenario: System defaults warranty months to 12 when nil and receipt data is present
    Given I have a signed in user for dashboard controller
    And I have a receipt processor that returns nil warranty length
    When I upload a receipt file
    Then the warranty months should default to 12

  Scenario: System filters warranties by expiring soon status
    Given I have a signed in user for dashboard controller
    And I have products with various statuses
    When I visit the dashboard with status filter "expiring_soon"
    Then I should only see expiring soon warranties

  Scenario: System sorts warranties by product name
    Given I have a signed in user for dashboard controller
    And I have products with various names
    When I visit the dashboard with sort "product_name"
    Then warranties should be sorted by product name

  Scenario: System sorts warranties by purchase date
    Given I have a signed in user for dashboard controller
    And I have products with various purchase dates
    When I visit the dashboard with sort "purchase_date"
    Then warranties should be sorted by purchase date

  Scenario: System sorts warranties by merchant
    Given I have a signed in user for dashboard controller
    And I have products with various merchants
    When I visit the dashboard with sort "merchant"
    Then warranties should be sorted by merchant

  Scenario: System returns warranties as JSON via API
    Given I have a signed in user for dashboard controller
    And I have products with warranty information
    When I visit the API warranties endpoint
    Then I should receive JSON with warranty data

  Scenario: System returns health status via API
    Given I have a signed in user for dashboard controller
    When I visit the API health endpoint
    Then I should receive JSON with health status

  Scenario: System resets Gmail connection
    Given I have a signed in user with Gmail connected
    When I reset the Gmail connection
    Then the Gmail tokens should be cleared

  Scenario: System disconnects Gmail
    Given I have a signed in user with Gmail connected
    When I disconnect Gmail
    Then I should be redirected to dashboard
    And the Gmail tokens should be cleared

  Scenario: System deletes warranty when product exists
    Given I have a signed in user for dashboard controller
    And I have a product
    When I delete the warranty
    Then the product should be destroyed

  Scenario: System returns not found when deleting non-existent warranty
    Given I have a signed in user for dashboard controller
    When I delete a non-existent warranty
    Then I should receive not found status for delete

  Scenario: System updates warranty without purchase date
    Given I have a signed in user for dashboard controller
    And I have a product
    When I update the warranty without purchase date
    Then the warranty should be updated

  Scenario: System sets warranty months to nil when form warranty length is zero
    Given I have a signed in user for dashboard controller
    When I upload a warranty with zero warranty length
    Then the warranty months should be nil for zero warranty length

  Scenario: System extracts return policy days from receipt data
    Given I have a signed in user for dashboard controller
    And I have a receipt processor that returns return policy days
    When I upload a receipt file
    Then the return policy days should be set from receipt data

  Scenario: System extracts return deadline from receipt data
    Given I have a signed in user for dashboard controller
    And I have a receipt processor that returns return deadline
    When I upload a receipt file
    Then the return deadline should be set from receipt data

  Scenario: System extracts warranty type from receipt data
    Given I have a signed in user for dashboard controller
    And I have a receipt processor that returns warranty type
    When I upload a receipt file
    Then the warranty type should be set from receipt data

  Scenario: System uses AI warranty info when available for manual upload
    Given I have a signed in user for dashboard controller
    And the AI service returns warranty info
    When I upload a warranty manually with merchant
    Then the warranty should use AI warranty info

  Scenario: System sets Gmail connected status
    Given I have a signed in user for dashboard controller
    When I visit the dashboard
    Then the Gmail connected status should be set

  Scenario: System deletes warranty and returns ok status
    Given I have a signed in user for dashboard controller
    And I have a product
    When I delete the warranty via API
    Then I should receive ok status

  Scenario: System returns not found when deleting non-existent warranty via API
    Given I have a signed in user for dashboard controller
    When I delete a non-existent warranty via API
    Then I should receive not found status for API delete

  Scenario: System updates warranty with purchase date
    Given I have a signed in user for dashboard controller
    And I have a product
    When I update the warranty with purchase date "2024-01-15"
    Then the warranty should be updated with purchase date

  Scenario: System looks up warranty info via API
    Given I have a signed in user for dashboard controller
    And the AI service returns warranty info
    When I lookup warranty info for product "iPhone" and merchant "Apple"
    Then I should receive JSON with warranty info

  Scenario: System shows error message when product name is blank without receipt file
    Given I have a signed in user for dashboard controller
    When I upload a warranty without product name and without receipt file
    Then I should be redirected to dashboard
    And I should see an alert "Product name is required"

  Scenario: System sets flash alert when extraction error exists
    Given I have a signed in user for dashboard controller
    And I have a receipt processor that raises an error
    When I upload a receipt file with product name
    Then I should be redirected to dashboard
    And the flash alert should be set with extraction error

  Scenario: System uses purchase date from receipt data when present
    Given I have a signed in user for dashboard controller
    And I have a receipt processor that returns purchase date
    When I upload a receipt file
    Then the purchase date should be set from receipt data

  Scenario: System defaults purchase date to today when not in receipt data
    Given I have a signed in user for dashboard controller
    And I have a receipt processor that returns no purchase date
    When I upload a receipt file
    Then the purchase date should default to today

  Scenario: System shows Vision API configuration error when no credentials available
    Given I have a signed in user for dashboard controller
    And the Vision API is not configured
    And the user does not have OAuth credentials
    When I upload a receipt file that fails to extract data
    Then I should be redirected to dashboard
    And I should see a Vision API configuration error

  Scenario: System shows generic extraction error when Vision API or OAuth is available
    Given I have a signed in user for dashboard controller
    And the Vision API is configured
    When I upload a receipt file that fails to extract data
    Then I should be redirected to dashboard
    And I should see a generic extraction error

  Scenario: System shows generic extraction error when OAuth is available but Vision API is not
    Given I have a signed in user for dashboard controller
    And the Vision API is not configured
    And the user has OAuth credentials
    When I upload a receipt file that fails to extract data
    Then I should be redirected to dashboard
    And I should see a generic extraction error
