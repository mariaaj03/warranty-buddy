# features/receipt_processor.feature
Feature: Receipt Processor
  As a system
  I want to process receipt images and PDFs
  So users can automatically extract warranty information

  Background:
    Given the receipt processing system is available

  # USER STORY 33: PDF Receipt Processing
  Scenario: System processes PDF receipt successfully
    As a user
    I want to upload PDF receipts
    So I can extract warranty information from digital receipts
    When I process a PDF receipt with valid content
    Then it should extract text from the PDF
    And it should parse the receipt data
    And it should return structured warranty information

  Scenario: System handles invalid PDF data
    When I process an empty PDF
    Then it should return nil
    And it should not raise any errors

  # USER STORY 34: Image Receipt Processing
  Scenario: System processes image receipt with OCR
    As a user
    I want to upload image receipts
    So I can extract warranty information from photos
    When I process an image receipt with valid content
    Then it should extract text using OCR
    And it should parse the receipt data
    And it should return structured warranty information

  Scenario: System handles OCR permission errors gracefully
    As a user
    I want the system to work even if OCR fails
    So I can still get some warranty information
    When I process an image but OCR permissions are denied
    Then it should fall back to AI extraction
    And it should return AI-extracted warranty information

  Scenario: System processes image with AI when OCR returns no text
    When I process an image receipt that OCR cannot read
    Then it should use AI extraction as fallback
    And it should return AI-extracted warranty information

  # USER STORY 35: Merchant Extraction
  Scenario: System extracts merchant from common retailers
    As a system
    I want to identify major retailers from receipt text
    So users see familiar merchant names
    When I extract merchant from receipt text containing "Best Buy"
    Then the merchant should be extracted from receipt as "Best Buy"

  Scenario: System extracts merchant from store patterns
    When I extract merchant from text "Thank you for shopping at Target Store"
    Then the merchant should be extracted from receipt as "Target"

  Scenario: System handles unknown merchants
    When I extract merchant from text with no recognizable merchant
    Then the merchant from receipt should be nil

  # USER STORY 36: Date Extraction and Parsing
  Scenario: System extracts purchase date from various formats
    As a system
    I want to parse different date formats from receipts
    So I work with receipts from any merchant
    When I extract date from receipt with "Purchase Date: January 15, 2024"
    Then the purchase date should be "2024-01-15"

  Scenario: System calculates purchase date from warranty end date
    When I extract date from receipt with "Coverage End Date: January 15, 2026" and "24 months warranty"
    Then the purchase date should be calculated as "2024-01-15"

  Scenario: System handles MM/DD/YYYY date format
    When I extract date from receipt with "01/15/2024"
    Then the purchase date should be "2024-01-15"

  Scenario: System handles YYYY-MM-DD date format  
    When I extract date from receipt with "2024-01-15"
    Then the purchase date should be "2024-01-15"

  # USER STORY 37: Line Item Extraction
  Scenario: System extracts line items from receipt text
    As a system
    I want to find individual products on receipts
    So I can create separate warranties for each item
    When I extract items from receipt with product and price lines
    """
    iPhone 15 Pro Max
    Part Number: A12345
    Color: Natural Titanium
    $1,199.00
    
    AirPods Pro (2nd generation)
    Part Number: B67890
    $249.00
    """
    Then I should extract 2 line items
    And the first item should be "iPhone 15 Pro Max" with price 1199.00
    And the second item should be "AirPods Pro (2nd generation)" with price 249.00

  Scenario: System filters out invalid product names
    When I extract items from receipt containing invalid product names
    """
    Customer Service: 1-800-555-0123
    Payment Method: Credit Card
    iPhone 15 Pro
    $999.00
    Serial Number: ABC123
    """
    Then I should extract 1 line item
    And the item should be "iPhone 15 Pro"

  # USER STORY 38: Price and Total Extraction
  Scenario: System extracts total amount from receipt
    As a system
    I want to find the total purchase amount
    So I can validate the receipt data
    When I extract total from receipt with "Total: $1,234.56"
    Then the total amount should be 1234.56

  Scenario: System handles various total formats
    When I extract totals from different formats
      | format      | input              | expected |
      | US Dollar   | Total: $1,234.56   | 1234.56  |
      | European    | Total: 1.234,56    | 1234.56  |
      | Grand Total | Grand Total: $999  | 999.0    |
      | Amount Due  | Amount Due: $45.99 | 45.99    |
    Then all totals should be correctly extracted

  # USER STORY 39: Order Number Extraction
  Scenario: System extracts order numbers from receipts
    When I extract order number from receipt with "Order Number: ABC-123-456"
    Then the order number should be "ABC-123-456"

  Scenario: System extracts receipt numbers
    When I extract order number from receipt with "Receipt #: XYZ789"
    Then the order number should be "XYZ789"

  # USER STORY 40: AI Integration and Fallback
  Scenario: System uses AI when regex parsing fails
    As a system
    I want to use AI when pattern matching fails
    So I can still extract warranty information
    When I process receipt text that regex cannot parse
    And AI extraction returns valid receipt data
    Then it should return AI-extracted information
    And it should include warranty details

  Scenario: System prefers regex over AI when both succeed
    When I process receipt text that both regex and AI can parse
    And regex finds valid product names
    And AI also finds valid product names
    Then it should prefer regex results
    And it should return regex-extracted information

  # USER STORY 41: Error Handling and Edge Cases
  Scenario: System handles empty or blank content
    When I process empty receipt content
    Then it should return nil
    And it should not raise any errors

  Scenario: System handles corrupted image data
    When I process corrupted image data
    Then it should handle the error gracefully
    And it should return nil

  Scenario: System cleans up temporary files
    When I process multiple receipts
    Then it should create temporary files during processing
    And it should clean up all temporary files after processing

  # USER STORY 42: Date Parsing Edge Cases
  Scenario: System handles invalid dates gracefully
    When I parse date string "February 30, 2024"
    Then it should return nil
    And it should not raise any errors

  Scenario: System handles various date string formats
    When I parse different date string formats
      | format           | input        | expected     |
      | MM/DD/YY         | 01/15/24     | 2024-01-15   |
      | MM/DD/YYYY       | 01/15/2024   | 2024-01-15   |
      | YYYY-MM-DD       | 2024-01-15   | 2024-01-15   |
      | Month DD, YYYY   | Jan 15, 2024 | 2024-01-15   |
    Then all dates should be correctly parsed

  # USER STORY 43: Product Name Validation
  Scenario: System validates product names
    When I validate product names for quality
      | name                    | valid |
      | iPhone 15 Pro          | true  |
      | Customer Service       | false |
      | 12345                  | false |
      | $99.99                 | false |
      | AB                     | false |
      | MacBook Pro 14"        | true  |
    Then the validation results should match expected values

  # USER STORY 44: Price Parsing Edge Cases
  Scenario: System handles various price formats
    When I parse different price formats
      | format              | input     | expected |
      | US with commas      | 1,234.56  | 1234.56  |
      | European format     | 1.234,56  | 1234.56  |
      | Simple decimal      | 999.99    | 999.99   |
      | No decimal          | 1234      | 1234.0   |
      | With currency       | $1,234.56 | 1234.56  |
    Then all prices should be correctly parsed

  # USER STORY 45: AI Result Formatting
  Scenario: System formats AI results correctly
    When I format AI extraction results with complete data
    """
    {
      "product_name": "iPhone 15 Pro",
      "merchant": "Apple Store", 
      "purchase_date": "2024-01-15",
      "warranty_length_months": 12,
      "warranty_type": "Limited Warranty",
      "return_policy_days": 30,
      "return_deadline": "2024-02-14"
    }
    """
    Then it should format as structured receipt data
    And it should include warranty information
    And it should parse dates correctly