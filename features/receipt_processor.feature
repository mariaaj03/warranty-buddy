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
    Then the extracted purchase date should be "2024-01-15"

  Scenario: System calculates purchase date from warranty end date
    When I extract date from receipt with "Coverage End Date: January 15, 2026" and "24 months warranty"
    Then the purchase date should be calculated as "2024-01-15"

  # USER STORY 38: Price and Total Extraction

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
    Then the extracted order number should be "ABC-123-456"

  # USER STORY 41: Error Handling and Edge Cases

  Scenario: System handles corrupted image data
    When I process corrupted image data
    Then it should handle the error gracefully
    And the result should be nil

  # USER STORY 42: Date Parsing Edge Cases
  Scenario: System handles invalid dates gracefully
    When I parse date string "February 30, 2024"
    Then the date parsing should return nil
    And it should not raise any errors

  Scenario: System handles various date string formats
    When I parse different date string formats
      | format           | input        | expected     |
      | MM/DD/YY         | 01/15/24     | 2024-01-15   |
      | MM/DD/YYYY       | 01/15/2024   | 2024-01-15   |
      | YYYY-MM-DD       | 2024-01-15   | 2024-01-15   |
      | Month DD, YYYY   | Jan 15, 2024 | 2024-01-15   |
    Then all dates should be correctly parsed

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

  # Additional coverage scenarios for extract_items_from_receipt
  Scenario: System skips lines with email addresses when extracting items
    When I extract items from receipt with email addresses
    Then it should skip lines containing email addresses

  Scenario: System skips numeric-only lines when extracting items
    When I extract items from receipt with numeric-only lines
    Then it should skip numeric-only lines

  Scenario: System skips dollar-sign-only lines when extracting items
    When I extract items from receipt with dollar-sign lines
    Then it should skip dollar-sign-only lines

  Scenario: System skips date format lines when extracting items
    When I extract items from receipt with date format lines
    Then it should skip date format lines

  Scenario: System skips time format lines when extracting items
    When I extract items from receipt with time format lines
    Then it should skip time format lines

  Scenario: System extracts items with Part Number on next line
    When I extract items from receipt with Part Number format
    Then it should find product name before Part Number
    And it should find price after Part Number

  Scenario: System skips blank previous lines when looking backwards from price
    When I extract items from receipt with blank lines before price
    Then it should skip blank lines when searching backwards

  Scenario: System skips excluded phrases in previous lines
    When I extract items from receipt with excluded phrases before price
    Then it should skip lines with excluded phrases

  Scenario: System skips various invalid patterns in previous lines
    When I extract items from receipt with invalid patterns before price
    Then it should skip invalid pattern lines

  Scenario: System finds valid product names when looking backwards from price
    When I extract items from receipt with valid product name before price
    Then it should extract the product name
    And it should match it with the price

  # Additional coverage for validation and edge cases
  Scenario: System validates product names correctly
    When I validate product names with various inputs
      | name              | valid |
      | iPhone 15 Pro     | true  |
      | customer service  | false |
      | 12345             | false |
      | $999              | false |
      | AB                | false |
      | Total             | false |
    Then all product name validations should be correct

  Scenario: System parses dates with year adjustment
    When I parse date string "01/15/24"
    Then it should adjust year to 2024

  Scenario: System parses dates with 2-digit years less than 50
    When I parse date string "01/15/24"
    Then the parsed year should be 2024

  Scenario: System parses dates with 2-digit years 50 or greater
    When I parse date string "01/15/99"
    Then the parsed year should be 1999

  Scenario: System uses AI result with fallback to regex values
    When I process receipt text where AI provides partial data
    Then it should use AI merchant or fallback to regex merchant
    And it should use AI purchase date or fallback to regex date
    And it should use regex total amount
    And it should use regex order number

  Scenario: System handles blank price strings
    When I parse price string ""
    Then the parsed price should be nil

  # Additional coverage for warranty period extraction
  Scenario: System extracts warranty period from "warranty period" pattern
    When I extract date from receipt with "Coverage End Date: January 15, 2026" and "warranty period: 24 months"
    Then the purchase date should be calculated using warranty period

  Scenario: System extracts warranty period from "months warranty" pattern
    When I extract date from receipt with "Coverage End Date: January 15, 2026" and "24 months warranty"
    Then the purchase date should be calculated using months warranty

  Scenario: System extracts warranty period from "year warranty" pattern
    When I extract date from receipt with "Coverage End Date: January 15, 2026" and "2 year warranty"
    Then the purchase date should be calculated using year warranty

  Scenario: System validates warranty end date is within valid range
    When I extract date from receipt with "Coverage End Date: January 15, 2026" and "24 months warranty"
    Then the warranty end date should be within valid range

  Scenario: System removes time from date strings
    When I extract date from receipt with "Purchase Date: January 15, 2024 14:30"
    Then the time should be removed from the date string

  # Merchant extraction patterns
  Scenario: System extracts merchant from "thank you for shopping at" pattern
    When I extract merchant from text "Thank you for shopping at Target Store"
    Then the merchant should be extracted from receipt as "Target Store"

  Scenario: System extracts merchant from "thank you for shopping at" with comma
    When I extract merchant from text "Thank you for shopping at Target Store, Inc."
    Then the merchant should be extracted from receipt as "Target Store"

  Scenario: System extracts merchant from "Store:" pattern
    When I extract merchant from text "Store: Best Buy"
    Then the merchant should be extracted from receipt as "Best Buy"

  # AI result fallback coverage
  Scenario: System uses regex total amount when AI total is missing
    When I process receipt text where AI provides partial data with total
    Then it should use regex total amount from fallback

  Scenario: System uses regex order number when AI order number is missing
    When I process receipt text where AI provides partial data with order number
    Then it should use regex order number from fallback

  # Regex parsing success path
  Scenario: System successfully parses receipt with line items
    When I process receipt text with valid line items
    Then it should return regex parsed result
    And it should set product name from first line item

  # Image extension determination
  Scenario: System determines image extension from filename
    When I determine image extension for filename "receipt.jpg"
    Then it should return extension ".jpg"

  Scenario: System defaults to jpg for unknown extensions
    When I determine image extension for filename "receipt.unknown"
    Then it should return extension ".jpg"

  Scenario: System returns nil for blank filename
    When I determine image extension for filename ""
    Then it should return extension nil

  # Additional coverage for process_image method
  Scenario: System processes image when AI result is not a receipt
    When I process an image where AI result is not a receipt
    Then it should use regex result instead of AI result

  Scenario: System processes image when both AI and regex find results
    When I process an image where both AI and regex find results
    Then it should compare product names
    And it should use AI result if product name is better

  Scenario: System processes image when regex product name is better than AI
    When I process an image where regex product name is better
    Then it should use regex result instead of AI result

  Scenario: System processes image when regex has no line items
    When I process an image where regex has no line items
    Then it should use AI result

  Scenario: System uses AI result when AI has valid product name and regex doesn't
    When I process an image where AI has valid product name and regex has invalid product name
    Then it should use AI result instead of regex result

  Scenario: System uses regex result when regex conditions are not met
    When I process an image where regex result has no line items or product name
    Then it should use AI result

  Scenario: System uses AI result with fallback values when regex result is nil
    When I process an image where AI extraction succeeds but regex result is nil
    Then it should use AI result with fallback values from nil regex result

  Scenario: System handles AI extraction failure in parse_receipt_text_first
    When I process an image where AI extraction fails in parse_receipt_text_first
    Then it should return the regex result

  Scenario: System handles PDF processing errors gracefully
    When I process a PDF that raises an error
    Then it should return nil without raising