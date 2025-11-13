# features/gmail_service.feature
Feature: Gmail Service
  As a system
  I want to parse receipt emails from Gmail
  So users can automatically import their warranty information

  Background:
    Given the Gmail service is available with valid authentication

  # USER STORY 62: Email Content Parsing
  Scenario: System extracts merchant from email headers
    When I extract merchant from email "orders@amazon.com"
    Then the merchant should be "Amazon"

  Scenario: System extracts merchant from sender name
    When I extract merchant from email "Best Buy <noreply@bestbuy.com>"
    Then the merchant should be "Best Buy"

  Scenario: System cleans merchant names properly
    When I extract merchant from email "Orders-Support@walmart.com"
    Then the merchant should be "Walmart"

  Scenario: System handles unknown email domains
    When I extract merchant from email "orders@unknownstore.com"
    Then the merchant should be "unknownstore"

  # USER STORY 64: Parser Selection and Fallback
  Scenario: System uses merchant-specific parser first
    Given I have an Amazon order email
    When I parse the email content with Amazon merchant
    Then it should use the Amazon parser first
    And it should return Amazon-parsed data

  Scenario: System falls back to generic parser when merchant parser fails
    Given I have an Amazon email that the Amazon parser cannot parse
    When I parse the email content
    Then it should fall back to EmailOrderParser
    And it should return generic parsed data


  # USER STORY 65: Product Name Extraction Strategies
  Scenario: System extracts product name from line items first
    Given I have an email with line items containing "iPhone 15 Pro"
    When I parse the email content
    Then it should extract product name from line items
    And the product name should be "iPhone 15 Pro"

  Scenario: System extracts product name from subject line when line items are empty
    Given I have an email with subject "Your tickets for Hamilton - The Musical"
    And the email has order number but no line items
    When I parse the email content
    Then it should extract product name from subject line
    And the product name should be "Hamilton - The Musical"

  Scenario: System extracts product name from email content when subject fails
    Given I have an email with product information in the body
    """
    Thank you for your purchase of MacBook Pro 16-inch.
    Your order will ship soon.
    """
    And the email has order number but no line items or clear subject
    When I parse the email content
    Then it should extract product name from email content
    And the product name should contain "MacBook Pro"

  Scenario: System uses AI extraction as last resort
    Given I have an email with order number but unclear product information
    And the AI service is available
    When I parse the email content
    Then it should attempt AI extraction
    And it should use AI-extracted product name
    And it should log the AI extraction attempt

  Scenario: System falls back to order number when all extraction fails
    Given I have an email with order number "ABC123" but no extractable product info
    When I parse the email content
    Then it should use fallback product name "Order ABC123"

  # USER STORY 66: Date Parsing
  Scenario: System parses email date from headers
    Given I have an email with date header "Mon, 15 Jan 2024 10:30:00 -0800"
    When I parse the email date
    Then the parsed date should be "2024-01-15"

  # USER STORY 67: Warranty and Return Policy Determination
  Scenario: System determines warranty length based on merchant
    When I determine warranty for merchant "Apple" and product "iPhone 15"
    Then the warranty length should be 12 months

  Scenario: System determines return policy by merchant
    When I determine return policy for merchant "Costco"
    Then the return policy should be 90 days

  Scenario: System uses default return policy for unknown merchants
    When I determine return policy for merchant "Unknown Store"
    Then the return policy should be 30 days
