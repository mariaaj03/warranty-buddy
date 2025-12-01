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






  # USER STORY 66: Date Parsing
  Scenario: System parses email date from headers
    Given I have an email with date header "Mon, 15 Jan 2024 10:30:00 -0800"
    When I parse the email date
    Then the parsed date should be "2024-01-15"

  # USER STORY 67: Warranty and Return Policy Determination
  Scenario: System determines warranty length based on merchant
    When I determine warranty for merchant "Apple" and product "iPhone 15"
    Then the warranty length should be 12 months

  Scenario: System processes message with valid parsed receipt
    Given I have a message that parses to a valid receipt
    When I parse receipt emails from Gmail
    Then it should add the receipt to parsed receipts
    And receipts found count should be incremented

  Scenario: System processes message with attachments
    Given I have Gmail messages with attachments
    When I parse receipt emails from Gmail
    Then it should process the attachments
    And it should add attachment receipts to parsed receipts

  Scenario: System rejects promotional emails
    Given I have a promotional email
    When I parse the email content for coverage
    Then the email content should return nil

  Scenario: System rejects emails from Digital merchant
    Given I have an email from Digital merchant
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

  Scenario: System cleans merchant name with special characters
    Given I have a merchant name with special characters
    When I clean the merchant name for coverage
    Then it should return cleaned merchant name

  Scenario: System extracts product name from email content with various patterns
    Given I have email content with product pattern matches
    When I extract product name from email content for pattern test
    Then the email content should return extracted product name

  Scenario: System extracts product name from subject with various patterns
    Given I have a subject line with product pattern matches
    When I extract product name from subject line
    Then the subject line should return extracted product name

  # Coverage scenarios for parse_receipt_emails
  Scenario: Service returns empty array when authorization is missing
    Given the Gmail API returns an authentication error
    When I parse receipt emails from Gmail
    Then it should return an empty array

  Scenario: Service processes message that returns nil parsed receipt
    Given I have a message that parses to nil
    When I parse receipt emails from Gmail
    Then it should not add the receipt to parsed receipts
    And receipts found count should not be incremented

  Scenario: Service processes message with no attachments
    Given I have a message with no attachments
    When I parse receipt emails from Gmail
    Then it should not process any attachments

  Scenario: Service handles error when processing individual message
    Given I have a message that raises an error during processing
    When I parse receipt emails from Gmail
    Then it should continue processing other messages
    And it should return parsed receipts from successful messages

  # Coverage scenarios for missing lines
  Scenario: Service extracts product name from subject when product name is blank and order number is present
    Given I have an email with product name in subject and order number
    When I parse the email content for coverage
    Then the email should extract product name from subject line

  Scenario: Service extracts product name from email content when subject extraction fails
    Given I have an email where subject extraction fails but content has product name
    When I parse the email content for coverage
    Then it should extract product name from email content

  Scenario: Service uses AI extraction when email text is long enough
    Given the AI service is configured for Gmail
    And I have an email with long text content that needs AI extraction
    When I parse the email content for coverage
    Then it should use AI to extract product name from long email text
