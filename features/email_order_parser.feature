# features/email_parsing.feature
Feature: Email Order Parser
  As a system
  I want to parse order emails accurately
  So users get correct warranty information from their receipts

  Background:
    Given the email parsing system is available

  # USER STORY 25: Email content validation
  Scenario: System distinguishes order emails from promotional emails
    As a system
    I want to identify legitimate order receipts
    So I don't create warranties from spam or marketing emails
    When I parse a promotional email with subject "Last minute gifts - Shop now!"
    Then the email should be rejected as non-order email
    And no parsing data should be returned

  Scenario: System identifies order confirmation emails
    As a system
    I want to recognize order confirmation patterns
    So I can process legitimate receipts
    When I parse an email with subject "Your Amazon.com order #123-4567890-1234567"
    Then the email should be accepted as an order email
    And parsing data should be returned

  # USER STORY 26: Merchant extraction
  Scenario: System extracts merchant from domain
    As a system
    I want to identify merchants from email domains
    So users see consistent merchant names
    When I parse an email from "auto-confirm@amazon.com"
    Then the merchant should be extracted as "Amazon"

  Scenario: System extracts merchant from meta tags
    As a system
    I want to use structured data when available
    So I get accurate merchant information
    When I parse an email with meta tag site_name "Best Buy"
    Then the merchant should be extracted as "Best Buy"

  # USER STORY 27: Order number extraction
  Scenario: System extracts order numbers from content
    As a system
    I want to find order numbers in email text
    So I can link warranties to specific purchases
    When I parse an email containing "Order Number: 123-4567890-1234567"
    Then the order number should be extracted as "123-4567890-1234567"

  Scenario: System extracts order numbers from subject lines
    As a system
    I want to find order numbers in email subjects
    So I don't miss order identification
    When I parse an email with order number in subject "Your order #ABC-123-DEF"
    Then the order number should be extracted as "ABC-123-DEF"

  # USER STORY 28: Date parsing
  Scenario: System parses various date formats
    As a system
    I want to handle different date formats
    So I work with emails from any merchant
    When I parse an email with purchase date "January 15, 2024"
    Then the purchase date should be parsed as "2024-01-15"

  Scenario: System handles MM/DD/YYYY format
    When I parse an email with purchase date "01/15/2024"
    Then the purchase date should be parsed as "2024-01-15"

  Scenario: System handles YYYY-MM-DD format
    When I parse an email with purchase date "2024-01-15"
    Then the purchase date should be parsed as "2024-01-15"

  # USER STORY 29: Line item extraction
  Scenario: System extracts products from HTML tables
    As a system
    I want to parse structured product tables
    So I can create warranties for individual items
    When I parse an email with HTML product table
    """
    <table>
      <tr><th>Item</th><th>Qty</th><th>Price</th></tr>
      <tr><td>iPhone 15 Pro</td><td>1</td><td>$999.00</td></tr>
      <tr><td>AirPods Pro</td><td>2</td><td>$249.00</td></tr>
    </table>
    """
    Then I should extract 2 email line items
    And the first email item should be "iPhone 15 Pro" with quantity 1 and price 999.00
    And the second email item should be "AirPods Pro" with quantity 2 and price 249.00

  # USER STORY 31: Error handling
  Scenario: System handles corrupted email content
    As a system
    I want to gracefully handle malformed emails
    So parsing errors don't crash the application
    When I parse an email with corrupted encoding
    Then the system should handle it gracefully
    And should not raise any exceptions

  

  # USER STORY 32: Complex merchant scenarios
  Scenario: System handles common merchant variations
    As a system
    I want to recognize major retailers
    So users see familiar merchant names
    When I parse emails from common merchants
      | domain              | expected_merchant |
      | orders@bestbuy.com  | Best Buy         |
      | noreply@walmart.com | Walmart          |
      | orders@target.com   | Target           |
      | auto@amazon.com     | Amazon           |
    Then the merchants should be extracted correctly

  # Additional coverage scenarios
  Scenario: System rejects promotional subject starting with "shop now"
    When I parse a promotional email with subject "Shop now and save 50%!"
    Then the email should be rejected as non-order email

  Scenario: System rejects promotional subject starting with "buy now"
    When I parse a promotional email with subject "Buy now - Limited time offer!"
    Then the email should be rejected as non-order email

  Scenario: System rejects promotional subject starting with "deal of"
    When I parse a promotional email with subject "Deal of the day - Don't miss out!"
    Then the email should be rejected as non-order email

  Scenario: System accepts email with order pattern in subject even without order number
    When I parse an email with subject "Your order has been shipped"
    Then the email should be accepted as an order email


  Scenario: System extracts merchant from merchant pattern in text
    When I parse an email containing "Sold by: Apple Store" for merchant extraction
    Then the merchant should be extracted as "Apple Store"

  Scenario: System extracts date from context near order number
    When I parse an email with order number and date nearby
    Then the purchase date should be extracted from context

  Scenario: System extracts line items with quantity
    When I parse an email containing "2x iPhone 15 Pro - $999.00"
    Then I should extract line items with quantity

  Scenario: System handles blank HTML content
    When I parse an email with blank HTML
    Then the system should handle it gracefully

  Scenario: System handles blank merchant name
    When I parse an email with blank merchant name
    Then the merchant should be cleaned to empty string

  Scenario: System parses price in US format with thousands separator
    When I parse an email with total "Total: $1,234.56"
    Then the total amount should be parsed as 1234.56

  Scenario: System parses price in European format
    When I parse an email with total "Total: 1.234,56"
    Then the total amount should be parsed as 1234.56

  Scenario: System parses price with European decimal comma
    When I parse an email with total "Total: 123,45"
    Then the total amount should be parsed as 123.45

  Scenario: System parses price with multiple dots as thousands separator
    When I parse an email with total "Total: 1.234.567"
    Then the total amount should be parsed as 1234567.0

  Scenario: System handles blank price string
    When I parse an email with blank price
    Then the price should be parsed as nil

  Scenario: System handles Chronic gem not available
    Given Chronic gem is not available
    When I parse an email with purchase date "yesterday"
    Then the system should handle it gracefully
    And it should log a warning about Chronic gem

  Scenario: System extracts date from table when no explicit date found
    When I parse an email with date in table
    Then the purchase date should be extracted from table

  Scenario: System extracts line item with nil quantity match
    When I parse an email containing line item without quantity "iPhone 15 Pro - $999.00"
    Then the line item should have default quantity 1

  Scenario: System extracts line item with nil name match
    When I parse an email containing line item with invalid name
    Then the line item should be skipped

  Scenario: System extracts line items from table without quantity column
    When I parse an email with table without quantity column
    Then the line items should have default quantity 1

  Scenario: System extracts line items from table without price column
    When I parse an email with table without price column
    Then the line items should have nil price