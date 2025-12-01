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

  Scenario: System uses generic parser for unknown merchants
    When I get parser for merchant "Unknown Store"
    Then it should return the Generic parser

  Scenario: System handles nil merchant gracefully
    When I get parser for merchant nil
    Then it should return the Generic parser

  Scenario: System selects Best Buy parser for "best buy" (lowercase)
    When I get parser for merchant "best buy"
    Then it should return the Best Buy parser

  # USER STORY 51: Amazon Parser - Price Parsing
  Scenario: Amazon parser handles various price formats
    When I parse Amazon prices in different formats
      | format              | input      | expected |
      | US with thousands   | 1,234.56   | 1234.56  |
      | Multiple dots       | 1.234.567  | 1234567  |
      | With currency       | $1,234.56  | 1234.56  |
    Then all Amazon prices should be correctly parsed

  Scenario: Amazon parser handles blank prices gracefully
    When I parse Amazon price ""
    Then the Amazon price should be nil

  Scenario: Amazon parser handles US format with thousands separator
    When I parse Amazon email with total "Order Total: 1,234.56"
    Then the total amount should be 1234.56

  Scenario: Amazon parser handles prices with multiple dots
    When I parse Amazon email with total "Total: 1.234.56"
    Then the total amount should be 123456.0

  Scenario: Amazon parser parses prices with thousands separator in line items
    When I parse Amazon email with product table
      """
      <html><body>
      <table>
        <tr><td>Expensive Item</td><td>1</td><td>$1,234.56</td></tr>
      </table>
      </body></html>
      """
    Then the first item should be "Expensive Item" with price 1234.56

  Scenario: Amazon parser parses prices with multiple dots in line items
    When I parse Amazon email with product table
      """
      <html><body>
      <table>
        <tr><td>European Price Item</td><td>1</td><td>1.234.56</td></tr>
      </table>
      </body></html>
      """
    Then the first item should be "European Price Item" with price 123456.0

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

  # Best Buy Parser - Price Parsing
  Scenario: Best Buy parser handles US format with thousands separator
    When I parse Best Buy email with total "Total: 1,234.56"
    Then the Best Buy total amount should be 1234.56

  Scenario: Best Buy parser handles prices with multiple dots
    When I parse Best Buy email with total "Total: 1.234.56"
    Then the Best Buy total amount should be 123456.0

  Scenario: Best Buy parser parses prices with thousands separator in line items
    When I parse Best Buy email with product table
      """
      <html><body>
      <table>
        <tr><td>Expensive Item</td><td>$1,234.56</td></tr>
      </table>
      </body></html>
      """
    Then the first Best Buy item should be "Expensive Item" with price 1234.56

  Scenario: Best Buy parser parses prices with multiple dots in line items
    When I parse Best Buy email with product table
      """
      <html><body>
      <table>
        <tr><td>European Price Item</td><td>1.234.56</td></tr>
      </table>
      </body></html>
      """
    Then the first Best Buy item should be "European Price Item" with price 123456.0

  Scenario: Best Buy parser handles various price formats
    When I parse Best Buy prices in different formats
      | format              | input      | expected |
      | US with thousands   | 1,234.56   | 1234.56  |
      | Multiple dots       | 1.234.56   | 123456.0 |
      | With currency        | $1,234.56  | 1234.56  |
    Then all Best Buy prices should be correctly parsed

  # Coverage scenarios for missing lines
  Scenario: Amazon parser skips table rows with less than 3 cells
    When I parse Amazon email with table row having 2 cells
    Then the line items should not include that row

  Scenario: Amazon parser skips product names with length 3 or less
    When I parse Amazon email with product name "AB"
    Then the line items should not include that product

  Scenario: Amazon parser handles price string that becomes blank after cleaning
    When I parse Amazon price "   "
    Then the Amazon price should be nil

  Scenario: Amazon parser handles price parsing exception
    When I parse Amazon price that causes exception
    Then the Amazon price should be nil

  Scenario: Amazon parser handles total amount ending with period
    When I parse Amazon email with total "Order Total: 1,234.56."
    Then the Amazon total amount should be 1234.56

  Scenario: Amazon parser handles multiple dots in price
    When I parse Amazon price "1.234.567"
    Then the Amazon price should be 1234567.0

  Scenario: Amazon parser handles total with trailing period
    When I parse Amazon email with total "Order Total: 1,234.56."
    Then the total amount should be 1234.56

   