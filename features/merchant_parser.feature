# features/merchant_parser.feature
Feature: Merchant-Specific Email Parsers
  As a system
  I want to parse emails using merchant-specific rules
  So I can extract accurate warranty information from different retailers

  Background:
    Given the merchant parser system is available

  # USER STORY 46: Parser Selection
  Scenario: System selects Amazon parser for Amazon emails
    As a system
    I want to use Amazon-specific parsing rules
    So I get accurate data from Amazon order emails
    When I get parser for merchant "Amazon"
    Then it should return the Amazon parser

  Scenario: System selects Best Buy parser for Best Buy emails
    When I get parser for merchant "Best Buy"
    Then it should return the Best Buy parser

  Scenario: System uses generic parser for unknown merchants
    When I get parser for merchant "Unknown Store"
    Then it should return the Generic parser

  Scenario: System handles nil merchant gracefully
    When I get parser for merchant nil
    Then it should return the Generic parser


  # USER STORY 51: Amazon Parser - Price Parsing
  Scenario: Amazon parser handles various price formats
    When I parse Amazon prices in different formats
      | format              | input      | expected |
      | US with thousands   | 1,234.56   | 1234.56  |
      | European format     | 1.234,56   | 1234.56  |
      | Simple European     | 123,45     | 123.45   |
      | Multiple dots       | 1.234.567  | 1234567  |
      | With currency       | $1,234.56  | 1234.56  |
    Then all Amazon prices should be correctly parsed

  Scenario: Amazon parser handles blank prices gracefully
    When I parse Amazon price ""
    Then the Amazon price should be nil

  # USER STORY 52: Best Buy Parser - Order Number Extraction
  Scenario: Best Buy parser extracts alphanumeric order numbers
    When I parse Best Buy email with order number "BBY01-ABC123DEF"
    """
    <html><body>
    <p>Best Buy Order #BBY01-ABC123DEF is ready for pickup.</p>
    </body></html>
    """
    Then the Best Buy order number should be "BBY01-ABC123DEF"

  Scenario: Best Buy parser extracts from order number field
    When I parse Best Buy email with text "Order Number: BESTBUY-12345678"
    Then the Best Buy order number should be "BESTBUY-12345678"

  # USER STORY 53: Best Buy Parser - Date Extraction
  Scenario: Best Buy parser extracts order date
    When I parse Best Buy email with date text "Order Date: January 15, 2024"
    Then the Best Buy purchase date should be "2024-01-15"


  # USER STORY 54: Best Buy Parser - Line Items
  Scenario: Best Buy parser extracts products from table
    When I parse Best Buy email with product table
    """
    <html><body>
    <table>
      <tr><td>MacBook Pro 14"</td><td>$1,999.00</td></tr>
      <tr><td>Magic Mouse</td><td>$79.00</td></tr>
    </table>
    </body></html>
    """
    Then I should extract 2 line items from Best Buy parser
    And the first Best Buy item should be "MacBook Pro 14\"" with price 1999.0
    And the second Best Buy item should be "Magic Mouse" with price 79.0

  Scenario: Best Buy parser assigns default quantity
    When I parse Best Buy email with simple product table
    """
    <html><body>
    <table>
      <tr><td>iPad Air</td><td>$599.00</td></tr>
    </table>
    </body></html>
    """
    Then I should extract 1 line items from Best Buy parser
    And the Best Buy item should have quantity 1

  # USER STORY 56: Best Buy Parser - Price Parsing
  Scenario: Best Buy parser handles price formats consistently
    When I parse Best Buy prices in different formats
      | format            | input     | expected |
      | US format         | 2,199.99  | 2199.99  |
      | European format   | 2.199,99  | 2199.99  |
      | Simple decimal    | 999.99    | 999.99   |
      | With currency     | $599.00   | 599.0    |
    Then all Best Buy prices should be correctly parsed

  # USER STORY 57: Generic Parser Integration
  Scenario: Generic parser uses EmailOrderParser for unknown merchants
    When I parse generic email with unknown merchant
    """
    <html><body>
    <p>Order confirmation from Unknown Store</p>
    <p>iPhone 15 Pro - $999.00</p>
    </body></html>
    """
    Then it should use the EmailOrderParser
    And it should return parsed order data

  Scenario: Generic parser handles parsing failures gracefully
    When I parse generic email with unparseable content
    """
    <html><body>
    <p>Invalid email content</p>
    </body></html>
    """
    Then it should return nil from generic parser

  # USER STORY 58: Error Handling and Edge Cases
  Scenario: Amazon parser handles empty HTML gracefully
    When I parse Amazon email with empty content
    Then it should return Amazon parser results with nil values

  Scenario: Best Buy parser handles malformed HTML
    When I parse Best Buy email with malformed HTML
    """
    <html><body><table><tr><td>Broken HTML
    """
    Then it should handle the error gracefully for Best Buy
    And it should return Best Buy parser results

  Scenario: Parsers handle missing required elements
    When I parse Amazon email without order information
    """
    <html><body>
    <p>This is not an order email</p>
    </body></html>
    """
    Then the Amazon parser should return empty results

  # USER STORY 59: Case Sensitivity
  Scenario: Parser selection is case insensitive
    When I get parser for merchant "AMAZON"
    Then it should return the Amazon parser

  Scenario: Parser selection handles mixed case
    When I get parser for merchant "Best buy"
    Then it should return the Best Buy parser

  # USER STORY 60: Integration Testing
  Scenario: Complete Amazon order parsing workflow
    When I parse a complete Amazon order email
    """
    <html><body>
    <h1>Your Amazon.com order #123-4567890-1234567</h1>
    <p>Ordered on January 15, 2024</p>
    <table>
      <tr><td>Item</td><td>Qty</td><td>Price</td></tr>
      <tr><td>iPhone 15 Pro</td><td>1</td><td>$999.00</td></tr>
      <tr><td>Case for iPhone</td><td>1</td><td>$29.99</td></tr>
    </table>
    <p>Order Total: $1,028.99</p>
    </body></html>
    """
    Then it should return complete Amazon order data
    And the Amazon merchant should be "Amazon"
    And the order number should be "123-4567890-1234567"
    And the purchase date should be "2024-01-15"
    And it should have 2 line items
    And the total should be 1028.99

   