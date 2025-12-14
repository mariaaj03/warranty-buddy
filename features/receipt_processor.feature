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

  Scenario: System extracts items with Part Number pattern
    When I extract items from receipt with Part Number pattern
    Then it should extract product with price from Part Number section


  Scenario: System skips prev_line when blank
    When I extract items from receipt with blank lines before price for prev_line test
    Then it should skip blank lines and find valid product name

  Scenario: System skips prev_line matching excluded patterns
    When I extract items from receipt with excluded phrases before price for prev_line test
    Then it should skip excluded phrases and find valid product name

  Scenario: System skips prev_line matching email pattern
    When I extract items from receipt with email before price for prev_line test
    Then it should skip email and find valid product name

  Scenario: System skips prev_line matching numeric patterns
    When I extract items from receipt with numeric lines before price for prev_line test
    Then it should skip numeric lines and find valid product name

  Scenario: System skips prev_line matching date patterns
    When I extract items from receipt with date lines before price for prev_line test
    Then it should skip date lines and find valid product name

  Scenario: System skips prev_line matching time patterns
    When I extract items from receipt with time lines before price for prev_line test
    Then it should skip time lines and find valid product name

  Scenario: System skips prev_line matching part number patterns
    When I extract items from receipt with part number lines before price for prev_line test
    Then it should skip part number lines and find valid product name

  Scenario: System extracts product when prev_line matches product pattern
    When I extract items from receipt with valid product pattern before price
    Then it should extract the product name from prev_line pattern

  Scenario: System calculates purchase date from warranty end date with year warranty
    When I extract date from receipt with warranty end date and year warranty
    Then the purchase date should be calculated correctly

  Scenario: System removes time from date string
    When I extract date from receipt with time in date string
    Then the date should be parsed without time

  Scenario: System validates date range for warranty end date
    When I extract date from receipt with warranty end date in valid range
    Then the purchase date should be calculated

  Scenario: System parses date string with year adjustment
    When I parse date string with two-digit year less than 50
    Then it should adjust year to 2000s

  Scenario: System parses date string with year adjustment for 1900s
    When I parse date string with two-digit year between 50 and 99
    Then it should adjust year to 1900s

  Scenario: System validates product name with invalid terms
    When I validate product name containing invalid terms
    Then the validation should return false

  Scenario: System validates product name with length check
    When I validate product name shorter than 3 characters
    Then the validation should return false

  Scenario: System validates product name matching numeric pattern
    When I validate product name that is only numbers
    Then the validation should return false

  Scenario: System validates product name matching dollar pattern
    When I validate product name starting with dollar sign
    Then the validation should return false

  Scenario: System formats AI result with merchant fallback
    When I format AI extraction results with missing merchant
    Then it should use merchant from regex result

  Scenario: System formats AI result with purchase date fallback
    When I format AI extraction results with missing purchase date
    Then it should use purchase date from regex result

  Scenario: System uses line items product name when available
    When I process receipt text with line items
    Then it should use first line item name as product name

  Scenario: System determines image extension for various formats
    When I determine image extension for filename
    Then it should return correct extension

  Scenario: System creates temp file with extension
    When I create temp file with data and extension
    Then it should create and track temp file


  Scenario: System handles EU price format with period thousands separator
    When I parse price string "1.234,56"
    Then the parsed price should be 1234.56

  Scenario: System handles price with only comma as decimal separator
    When I parse price string "123,45"
    Then the parsed price should be 123.45

  Scenario: System handles price with only period as thousands separator
    When I parse price string "1.234"
    Then the parsed price should be 1234.0



  Scenario: System extracts merchant from Ulta email
    When I extract merchant from text "ULTA Beauty"
    Then the merchant should be extracted from receipt as "Ulta"




  Scenario: System handles warranty end date with 1 year warranty
    When I extract date from receipt with "Expires: Dec 31, 2025" and "1 year warranty"
    Then the purchase date should be calculated as "2024-12-31"



