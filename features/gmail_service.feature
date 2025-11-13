# features/gmail_service.feature
Feature: Gmail Service
  As a system
  I want to parse receipt emails from Gmail
  So users can automatically import their warranty information

  Background:
    Given the Gmail service is available with valid authentication

  # USER STORY 61: Core Email Processing
  Scenario: System processes Gmail messages successfully
    As a user
    I want to parse my Gmail for receipts
    So I can automatically track my warranties
    Given I have 3 Gmail messages in my inbox
    When I parse receipt emails from Gmail
    Then it should process all 3 messages
    And it should return parsed receipt data
    And it should log the processing results

  Scenario: System handles Gmail API errors gracefully
    Given the Gmail API returns an authentication error
    When I parse receipt emails from Gmail
    Then it should handle the API error gracefully
    And it should return an empty array
    And it should log the error

  Scenario: System cleans up after processing
    Given I have Gmail messages with attachments
    When I parse receipt emails from Gmail
    Then it should process the attachments
    And it should clean up temporary files after processing

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

  # USER STORY 63: Promotional Email Filtering
  Scenario: System rejects promotional emails
    When I parse email with promotional subject "Select items to arrive in time for Valentine's Day"
    Then it should reject the email as promotional
    And it should return nil for parsed data

  Scenario: System rejects newsletter emails
    When I parse email with promotional subject "Newsletter: Latest deals and offers"
    Then it should reject the email as promotional

  Scenario: System rejects marketing emails by subject pattern
    When I parse email with promotional subject "Shop now for amazing deals"
    Then it should reject the email as promotional

  Scenario: System accepts order confirmation emails
    When I parse email with order subject "Your Amazon order #123-456-789 has shipped"
    Then it should accept the email for processing
    And it should parse the order information

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

  Scenario: System rejects emails with no line items and no order number
    Given I have an email with no extractable order information
    When I parse the email content
    Then it should return nil
    And it should not create a receipt

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

  Scenario: System handles invalid email dates gracefully
    Given I have an email with invalid date header "Invalid Date Format"
    When I parse the email date
    Then it should return nil
    And it should not raise an error

  Scenario: System uses today's date when no date is available
    Given I have an email with no date information
    When I parse the email content
    Then it should use today's date as purchase date

  # USER STORY 67: Warranty and Return Policy Determination
  Scenario: System determines warranty length based on merchant
    When I determine warranty for merchant "Apple" and product "iPhone 15"
    Then the warranty length should be 12 months

  Scenario: System determines warranty length based on product type
    When I determine warranty for unknown merchant and product "Samsung Refrigerator"
    Then the warranty length should be 24 months

  Scenario: System uses Google Search for warranty information
    Given Google Search service is available
    When I determine warranty for product "Sony WH-1000XM5 Headphones"
    Then it should attempt Google Search for warranty info
    And it should use the found warranty information

  Scenario: System falls back to default warranty when search fails
    Given Google Search service is unavailable
    When I determine warranty for unknown product
    Then it should use default warranty of 12 months

  Scenario: System determines return policy by merchant
    When I determine return policy for merchant "Costco"
    Then the return policy should be 90 days

  Scenario: System uses default return policy for unknown merchants
    When I determine return policy for merchant "Unknown Store"
    Then the return policy should be 30 days

  # USER STORY 68: Attachment Processing
  Scenario: System processes PDF receipt attachments
    Given I have an email with a PDF receipt attachment
    When I process the email attachments
    Then it should extract data from the PDF
    And it should return receipt information from the attachment

  Scenario: System processes image receipt attachments
    Given I have an email with an image receipt attachment
    When I process the email attachments
    Then it should extract data from the image using OCR
    And it should return receipt information from the attachment

  Scenario: System handles attachment processing errors gracefully
    Given I have an email with a corrupted attachment
    When I process the email attachments
    Then it should handle the attachment error gracefully
    And it should continue processing other attachments
    And it should log the attachment processing error

  Scenario: System skips unsupported attachment types
    Given I have an email with a text file attachment
    When I process the email attachments
    Then it should skip the unsupported attachment type
    And it should not process the text file

  # USER STORY 69: Product Name Extraction from Subject Lines
  Scenario: System extracts event tickets from subject
    When I extract product name from subject "Your tickets for Hamilton - Order #ABC123"
    Then the extracted product name should be "Hamilton"

  Scenario: System extracts purchase items from subject
    When I extract product name from subject "Receipt for iPhone 15 Pro - Order #XYZ789"
    Then the extracted product name should be "iPhone 15 Pro"

  Scenario: System handles complex subject patterns
    When I extract product name from subject "You bought 2 tickets for The Lion King - February 14, 2024"
    Then the extracted product name should be "The Lion King"

  Scenario: System rejects promotional subjects
    When I extract product name from subject "Select items to arrive in time for Valentine's Day"
    Then it should return nil for promotional subject

  Scenario: System extracts from order confirmation subjects
    When I extract product name from subject "MacBook Pro Confirmation - Best Buy Order #BB123"
    Then the extracted product name should be "MacBook Pro"

  # USER STORY 70: Email Content Analysis
  Scenario: System extracts products from structured email content
    When I extract product from email content containing "Item: iPhone 15 Pro Max"
    Then the extracted product should be "iPhone 15 Pro Max"

  Scenario: System extracts products using description patterns
    When I extract product from email content containing "Description: Samsung Galaxy S24 Ultra"
    Then the extracted product should be "Samsung Galaxy S24 Ultra"

  Scenario: System filters out non-product lines
    When I extract product from email content containing order details and product info
    """
    Order Number: 12345
    Shipping Address: 123 Main St
    MacBook Pro 16-inch Space Gray
    Total: $2,499.00
    """
    Then the extracted product should be "MacBook Pro 16-inch Space Gray"

  Scenario: System handles HTML content extraction
    When I extract product from HTML email content
    """
    <html><body>
    <div>Thank you for purchasing</div>
    <div>AirPods Pro (2nd generation)</div>
    <div>$249.00</div>
    </body></html>
    """
    Then the extracted product should be "AirPods Pro (2nd generation)"

  # USER STORY 71: Edge Cases and Error Handling
  Scenario: System handles empty email content gracefully
    Given I have an email with empty HTML and text content
    When I parse the email content
    Then it should return nil
    And it should not raise an error

  Scenario: System handles malformed email headers
    Given I have an email with malformed from header
    When I extract merchant from the email headers
    Then it should handle the malformed header gracefully

  Scenario: System processes large volumes of emails efficiently
    Given I have 100 Gmail messages in my inbox
    When I parse receipt emails from Gmail
    Then it should process all messages within reasonable time
    And it should provide progress logging
    And it should return results for valid receipts only

  Scenario: System handles missing Gmail service authorization
    Given the Gmail service has no authorization
    When I parse receipt emails from Gmail
    Then it should return an empty array immediately
    And it should not attempt to fetch messages

  # USER STORY 72: AI Integration
  Scenario: System uses AI when configured properly
    Given the AI service is properly configured with API key
    And I have an email with unclear product information
    When I parse the email content
    Then it should attempt AI extraction
    And it should use the AI-extracted product name

  Scenario: System handles AI service failures gracefully
    Given the AI service throws an error
    And I have an email requiring AI extraction
    When I parse the email content
    Then it should handle the AI error gracefully
    And it should fall back to order number naming
    And it should log the AI failure

  Scenario: System skips AI when not configured
    Given the AI service has no API key configured
    And I have an email requiring AI extraction
    When I parse the email content
    Then it should skip AI extraction
    And it should log that AI is not configured

  # USER STORY 73: Merchant Name Cleaning
  Scenario: System removes common email prefixes from merchant names
    When I clean merchant name "noreply-orders@bestbuy.com"
    Then the cleaned name should be "bestbuy"

  Scenario: System removes special characters from merchant names
    When I clean merchant name "Best-Buy Orders (Support)"
    Then the cleaned name should be "Best Buy Orders"

  Scenario: System handles complex merchant name patterns
    When I clean merchant name '"Amazon Orders" <no-reply@amazon.com>'
    Then the cleaned name should be "Amazon Orders"

  # USER STORY 74: Integration and Data Flow
  Scenario: Complete Gmail parsing workflow
    Given I have a complete Amazon order email in Gmail
    """
    Subject: Your Amazon.com order #123-4567890-1234567
    From: Amazon <orders@amazon.com>
    Date: Mon, 15 Jan 2024 10:30:00 -0800
    
    <html><body>
    <p>Your order has shipped:</p>
    <table>
      <tr><td>iPhone 15 Pro</td><td>1</td><td>$999.00</td></tr>
    </table>
    <p>Order Total: $999.00</p>
    </body></html>
    """
    When I parse receipt emails from Gmail
    Then it should return 1 parsed receipt
    And the receipt should have merchant "Amazon"
    And the receipt should have product name "iPhone 15 Pro"
    And the receipt should have order number "123-4567890-1234567"
    And the receipt should have purchase date "2024-01-15"
    And the receipt should have warranty length 12 months
    And the receipt should have return policy 30 days
    And the receipt should have source "gmail_parsed"