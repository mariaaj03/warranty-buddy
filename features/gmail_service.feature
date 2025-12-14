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

  # Merchant extraction edge cases
  Scenario: System extracts merchant from various email domains
    When I extract merchant from email "noreply@target.com"
    Then the merchant should be "Target"
    When I extract merchant from email "orders@costco.com"
    Then the merchant should be "Costco"
    When I extract merchant from email "support@apple.com"
    Then the merchant should be "Apple"
    When I extract merchant from email "noreply@sephora.com"
    Then the merchant should be "Sephora"
    When I extract merchant from email "orders@nordstrom.com"
    Then the merchant should be "Nordstrom"


  Scenario: System handles merchant name from sender name with quotes
    When I extract merchant from email "\"Best Buy\" <orders@bestbuy.com>"
    Then the merchant should be "Best Buy"


  # USER STORY 66: Date Parsing
  Scenario: System parses email date from headers
    Given I have an email with date header "Mon, 15 Jan 2024 10:30:00 -0800"
    When I parse the email date
    Then the parsed date should be "2024-01-15"

 

  # USER STORY 67: Warranty and Return Policy Determination
  Scenario: System determines warranty length based on merchant
    When I determine warranty for merchant "Apple" and product "iPhone 15"
    Then the warranty length should be 12 months



  Scenario: System rejects promotional emails
    Given I have a promotional email
    When I parse the email content for coverage
    Then the email content should return nil

  Scenario: System falls back to generic parser when merchant parser fails
    Given I have an email where merchant parser returns nil
    When I parse the email content for coverage
    Then it should use generic parser
    And the email content should return parsed data

  Scenario: System extracts order number from subject when missing
    Given I have an email with order number in subject only
    When I parse the email content for coverage
    Then it should extract order number from subject

  Scenario: System extracts product name from subject line
    Given I have an email with product name in subject
    When I parse the email content for coverage
    Then the email should extract product name from subject

  Scenario: System extracts product name from email content
    Given I have an email with product name in content
    When I parse the email content for coverage
    Then it should extract product name from content

  Scenario: System uses AI to extract product name when other methods fail
    Given the AI service is configured for Gmail
    And I have an email where product name needs AI extraction
    When I parse the email content for coverage
    Then it should use AI to extract product name

  Scenario: System falls back to order number as product name
    Given I have an email with only order number
    When I parse the email content for coverage
    Then it should use order number as product name



  Scenario: System determines warranty for appliances by product name
    When I determine warranty for merchant "Unknown" and product "Samsung Refrigerator"
    Then the warranty length should be 24 months
    When I determine warranty for merchant "Unknown" and product "Whirlpool Dishwasher"
    Then the warranty length should be 24 months


  Scenario: System handles blank HTML content
    Given I have blank HTML content
    When I extract text from HTML
    Then it should return empty string


 