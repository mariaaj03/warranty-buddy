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

  # Additional coverage scenarios
  Scenario: System handles messages that are not valid receipts
    Given I have Gmail messages that are not receipts
    When I parse receipt emails from Gmail
    Then it should skip invalid receipts
    And it should not add them to parsed receipts

  Scenario: System processes valid receipt and adds to parsed receipts
    Given I have Gmail messages with valid receipts
    When I parse receipt emails from Gmail
    Then it should add valid receipts to parsed receipts
    And the receipts found count should be greater than zero

  Scenario: System processes messages with attachments
    Given I have Gmail messages with attachments
    When I parse receipt emails from Gmail
    Then it should process attachments
    And it should include attachment receipts

  Scenario: System processes messages without attachments
    Given I have Gmail messages without attachments
    When I parse receipt emails from Gmail
    Then it should skip attachment processing

  Scenario: System processes PDF attachments
    Given I have Gmail messages with PDF attachments
    When I parse receipt emails from Gmail
    Then it should process PDF attachments

  Scenario: System processes image attachments
    Given I have Gmail messages with image attachments
    When I parse receipt emails from Gmail
    Then it should process image attachments

  Scenario: System skips unsupported attachment types
    Given I have Gmail messages with unsupported attachment types
    When I parse receipt emails from Gmail
    Then it should skip unsupported attachments

  Scenario: System uses fallback product name when line items are empty
    Given I have an email with no line items but has order number
    When I parse the email content
    Then it should use fallback product name "Unknown Product"

  Scenario: System extracts product name from subject with valid patterns
    When I extract product name from subject "Order for iPhone 15 Pro - Order #12345"
    Then it should extract "iPhone 15 Pro"

  Scenario: System skips invalid product name candidates from subject
    When I extract product name from subject with invalid candidates
    Then it should skip blank candidates
    And it should skip candidates that are too short
    And it should skip candidates that are too long
    And it should skip candidates with promotional keywords
    And it should skip candidates matching excluded patterns

  Scenario: System extracts product name from email content with valid patterns
    When I extract product name from email content with valid product lines
    Then it should extract the product name

  Scenario: System skips invalid product name candidates from email content
    When I extract product name from email content with invalid lines
    Then it should skip lines that are too short
    And it should skip lines that are too long
    And it should skip lines with excluded patterns
    And it should skip lines matching numeric or dollar patterns
    And it should skip candidates matching excluded patterns

  Scenario: System extracts product name from subject using extract_product_name_from_subject
    When I extract product name using extract_product_name_from_subject with "Receipt for iPhone 15 Pro"
    Then it should return product name "iPhone 15 Pro"

  Scenario: System returns Unknown Product for blank subject
    When I extract product name using extract_product_name_from_subject with ""
    Then it should return product name "Unknown Product"

  Scenario: System returns Unknown Product for promotional subjects
    When I extract product name using extract_product_name_from_subject with "Select items to arrive"
    Then it should return product name "Unknown Product"

  Scenario: System extracts product name from subject pattern match
    When I extract product name using extract_product_name_from_subject with "Order for MacBook Pro"
    Then it should return product name "MacBook Pro"

  Scenario: System skips product names with promotional keywords in extract_product_name_from_subject
    When I extract product name using extract_product_name_from_subject with "Order for Sale Item"
    Then it should return product name "Unknown Product"

  Scenario: System adds parsed receipt to receipts array
    Given I have a message that parses to a valid receipt
    When I parse receipt emails from Gmail
    Then it should add the receipt to parsed receipts

  Scenario: System processes attachments when they exist
    Given I have a message with attachments
    When I parse receipt emails from Gmail
    Then it should process the attachments
    And it should add attachment receipts to parsed receipts

  Scenario: System extracts merchant from email domain
    Given I have an email from "orders@amazon.com"
    When I extract merchant from headers
    Then the extracted merchant should be "Amazon"

  Scenario: System extracts merchant from sender name
    Given I have an email from "Best Buy <orders@bestbuy.com>"
    When I extract merchant from headers
    Then the extracted merchant should be "Best Buy"

  Scenario: System returns nil for blank merchant name
    Given I have a blank merchant name
    When I clean the merchant name
    Then it should return nil

  Scenario: System extracts product name from email content with pattern match
    Given I have email content with product pattern match
    When I extract product name from email content
    Then it should return the product name

  Scenario: System skips blank candidates in product name extraction
    Given I have email content with blank candidate
    When I extract product name from email content
    Then it should skip the blank candidate

  Scenario: System skips candidates matching excluded patterns in product name extraction
    Given I have email content with candidate matching excluded patterns
    When I extract product name from email content
    Then it should skip the excluded candidate

  Scenario: System returns empty string for blank HTML
    Given I have blank HTML content
    When I extract text from HTML
    Then it should return an empty string

  Scenario: System processes PDF attachment
    Given I have a PDF attachment
    When I process the attachment
    Then it should call process_pdf

  Scenario: System processes image attachment
    Given I have an image attachment
    When I process the attachment
    Then it should call process_image

  Scenario: System skips unsupported attachment type
    Given I have an unsupported attachment type
    When I process the attachment
    Then it should skip the attachment

  Scenario: System handles attachment processing error
    Given I have an attachment that will cause an error
    When I process the attachment
    Then it should handle the error gracefully

  # Coverage for parse_email_content branches
  Scenario: System rejects promotional emails with promotional keywords
    Given I have an email with promotional subject containing keywords
    When I parse the email content
    Then it should return nil

  Scenario: System rejects promotional emails with specific patterns
    Given I have an email with subject starting with "shop now"
    When I parse the email content
    Then it should return nil

  Scenario: System rejects emails from Digital merchant
    Given I have an email from Digital merchant
    When I parse the email content
    Then it should return nil

  Scenario: System uses merchant parser when it returns data
    Given I have an email that merchant parser can parse
    When I parse the email content
    Then it should use merchant parser data
    And it should not use generic parser

  Scenario: System falls back to generic parser when merchant parser returns nil
    Given I have an email that merchant parser cannot parse
    When I parse the email content
    Then it should use generic parser

  Scenario: System returns nil when both parsers return nil
    Given I have an email that neither parser can parse
    When I parse the email content
    Then it should return nil

  Scenario: System extracts order number from subject when missing from parsed data
    Given I have an email with order number in subject but not in parsed data
    When I parse the email content
    Then it should extract order number from subject

  Scenario: System returns nil when line items are empty and order number is blank
    Given I have an email with no line items and no order number
    When I parse the email content
    Then it should return nil

  Scenario: System processes email when line items are present
    Given I have an email with line items
    When I parse the email content
    Then it should extract product name from line items

  Scenario: System processes email when order number is present but no line items
    Given I have an email with order number but no line items
    When I parse the email content
    Then it should extract product name using fallback methods

  Scenario: System extracts product name from subject when line items have no product name
    Given I have an email with order number but blank product name in line items
    And the subject contains a product name
    When I parse the email content
    Then it should extract product name from subject

  Scenario: System extracts product name from email content when subject extraction fails
    Given I have an email with order number but blank product name
    And subject extraction returns nil
    When I parse the email content
    Then it should extract product name from email content

  Scenario: System tries AI extraction when other methods fail
    Given I have an email with order number but no product name found
    And subject and email content extraction both fail
    And the email text is long enough for AI extraction
    When I parse the email content
    Then it should attempt AI extraction

  Scenario: System uses AI result when AI extraction succeeds
    Given I have an email that requires AI extraction
    And the AI service is configured and returns product name
    When I parse the email content
    Then it should use AI extracted product name

  Scenario: System handles AI extraction when AI service is not configured
    Given I have an email that requires AI extraction
    And the AI service is not configured
    When I parse the email content
    Then it should use fallback product name

  Scenario: System handles AI extraction when AI returns no product name
    Given I have an email that requires AI extraction
    And the AI service returns result without product name
    When I parse the email content
    Then it should use fallback product name

  Scenario: System handles AI extraction failure gracefully
    Given I have an email that requires AI extraction
    And the AI service raises an error
    When I parse the email content
    Then it should use fallback product name

  Scenario: System skips AI extraction when email text is too short
    Given I have an email with order number but no product name
    And the email text is too short for AI extraction
    When I parse the email content
    Then it should use fallback product name without trying AI

  Scenario: System uses fallback product name when all extraction methods fail
    Given I have an email with order number but all extraction methods fail
    When I parse the email content
    Then it should use fallback product name "Order {order_number}"

  Scenario: System returns nil when product name is blank after all attempts
    Given I have an email with no product name and no order number
    When I parse the email content
    Then it should return nil

  Scenario: System adds parsed receipt to receipts array when parsed_receipt is truthy
    Given I have Gmail messages that will parse successfully
    When I parse receipt emails
    Then the parsed receipt should be added to receipts array
    And receipts found count should be incremented

  Scenario: System returns nil when merchant name is blank in clean_merchant_name
    Given I have a blank merchant name
    When I clean the merchant name
    Then it should return nil for blank merchant name

  Scenario: System processes image attachment with image mime type
    Given I have an attachment with image mime type
    When I process the attachment
    Then it should process the image attachment

  Scenario: System skips unsupported attachment type in process_attachments
    Given I have an attachment with unsupported mime type
    When I process the attachment
    Then it should skip the attachment

  Scenario: System skips attachment when receipt data has no merchant
    Given I have an attachment that returns receipt data without merchant
    When I process the attachment
    Then it should skip the attachment

  Scenario: System uses Unknown Product when primary item has no name
    Given I have an attachment with receipt data but no primary item name
    When I process the attachment
    Then the receipt should use "Unknown Product" as product name

  Scenario: System determines warranty length for attachment receipt
    Given I have an attachment with receipt data
    When I process the attachment
    Then it should determine warranty length for the receipt
