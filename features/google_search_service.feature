Feature: Google Search Service
  As a system
  I want to search for warranty information using Google Search API
  So that I can provide accurate warranty details to users

  # Initialization and Configuration
  Scenario: Service initializes with API credentials
    Given the Google Search API credentials are configured
    When I create a GoogleSearchService instance
    Then it should be initialized with API key and search engine ID

  Scenario: Service initializes without API credentials
    Given the Google Search API credentials are not configured
    When I create a GoogleSearchService instance
    Then it should be initialized without API key

  # lookup_warranty_info method
  Scenario: Lookup warranty info with valid product and merchant
    Given the Google Search API credentials are configured
    And the Google Search API returns valid warranty results
    When I lookup warranty info for product "MacBook Pro" from merchant "Apple"
    Then it should return warranty information
    And it should include warranty months
    And it should include return policy days
    And it should include source as "google_search"
    And it should include details array

  Scenario: Lookup warranty info with product only
    Given the Google Search API credentials are configured
    And the Google Search API returns valid warranty results
    When I lookup warranty info for product "iPhone 15" without merchant
    Then it should return warranty information
    And the search query should include the product name

  Scenario: Lookup warranty info when API keys are missing
    Given the Google Search API credentials are not configured
    When I lookup warranty info for product "Laptop" from merchant "Best Buy"
    Then it should return nil

  Scenario: Lookup warranty info when search returns no results
    Given the Google Search API credentials are configured
    And the Google Search API returns empty results
    When I lookup warranty info for product "Unknown Product" from merchant "Unknown Store"
    Then it should return nil

  Scenario: Lookup warranty info when search fails
    Given the Google Search API credentials are configured
    And the Google Search API request fails
    When I lookup warranty info for product "Product" from merchant "Merchant"
    Then it should return nil

  # search_warranty_question method
  Scenario: Search warranty question successfully
    Given the Google Search API credentials are configured
    And the Google Search API returns valid search results
    When I search for warranty question "What is the warranty period for laptops?"
    Then it should return an array of search results
    And each result should have title, snippet, and url
    And the search query should include "warranty coverage"

  Scenario: Search warranty question without API keys
    Given the Google Search API credentials are not configured
    When I search for warranty question "What is warranty?"
    Then it should return an empty array

  Scenario: Search warranty question when API returns error status
    Given the Google Search API credentials are configured
    And the Google Search API returns error status 403
    When I search for warranty question "What is warranty?"
    Then it should return an empty array
    And it should log an error

  Scenario: Search warranty question when request raises exception
    Given the Google Search API credentials are configured
    And the Google Search API request raises an exception
    When I search for warranty question "What is warranty?"
    Then it should return an empty array
    And it should log an error

  Scenario: Search warranty question with empty results
    Given the Google Search API credentials are configured
    And the Google Search API returns response with no items
    When I search for warranty question "What is warranty?"
    Then it should return an empty array

  # extract_warranty_info method (tested through lookup_warranty_info)
  Scenario: Extract warranty info with month warranty pattern
    Given the Google Search API credentials are configured
    And the Google Search API returns results with "12 months warranty"
    When I lookup warranty info for product "Laptop" from merchant "Best Buy"
    Then it should extract warranty months as 12

  Scenario: Extract warranty info with year warranty pattern
    Given the Google Search API credentials are configured
    And the Google Search API returns results with "1 year warranty"
    When I lookup warranty info for product "Laptop" from merchant "Best Buy"
    Then it should extract warranty months as 12

  Scenario: Extract warranty info with multiple warranty mentions
    Given the Google Search API credentials are configured
    And the Google Search API returns results with multiple warranty periods
    When I lookup warranty info for product "Laptop" from merchant "Best Buy"
    Then it should extract the highest warranty months

  Scenario: Extract return policy with day pattern
    Given the Google Search API credentials are configured
    And the Google Search API returns results with "30 days return policy"
    When I lookup warranty info for product "Laptop" from merchant "Best Buy"
    Then it should extract return policy days as 30

  Scenario: Extract return policy with multiple mentions
    Given the Google Search API credentials are configured
    And the Google Search API returns results with multiple return policy periods
    When I lookup warranty info for product "Laptop" from merchant "Best Buy"
    Then it should extract the highest return policy days

  Scenario: Extract warranty info with no warranty found
    Given the Google Search API credentials are configured
    And the Google Search API returns results without warranty information
    When I lookup warranty info for product "Laptop" from merchant "Best Buy"
    Then it should return warranty information with nil warranty months

  Scenario: Extract warranty info defaults return policy to 30 days
    Given the Google Search API credentials are configured
    And the Google Search API returns results without return policy
    When I lookup warranty info for product "Laptop" from merchant "Best Buy"
    Then it should default return policy days to 30

  Scenario: Extract warranty info when return policy is already found
    Given the Google Search API credentials are configured
    And the Google Search API returns results with "30 days return policy"
    When I lookup warranty info for product "Laptop" from merchant "Best Buy"
    Then it should extract return policy days as 30
    And it should not override existing return policy

  Scenario: Extract warranty info with year warranty pattern
    Given the Google Search API credentials are configured
    And the Google Search API returns results with "2 year warranty"
    When I lookup warranty info for product "Laptop" from merchant "Best Buy"
    Then it should extract warranty months as 24

  Scenario: Extract warranty info when warranty months already set and new value is lower
    Given the Google Search API credentials are configured
    And the Google Search API returns results with multiple warranty periods where first is higher
    When I lookup warranty info for product "Laptop" from merchant "Best Buy"
    Then it should keep the higher warranty months value

  Scenario: Lookup warranty info when search returns nil
    Given the Google Search API credentials are configured
    And the Google Search API returns nil results
    When I lookup warranty info for product "Unknown Product" from merchant "Unknown Store"
    Then it should return nil

  Scenario: Build query with merchant present
    Given the Google Search API credentials are configured
    And the Google Search API returns valid warranty results
    When I lookup warranty info for product "MacBook Pro" from merchant "Apple Store"
    Then the search query should include merchant "Apple Store"

  Scenario: Perform search when API returns error status
    Given the Google Search API credentials are configured
    And the Google Search API returns error status 500 for lookup
    When I lookup warranty info for product "Product" from merchant "Merchant"
    Then it should return nil
    And it should log a lookup error

  Scenario: Perform search when request raises exception
    Given the Google Search API credentials are configured
    And the Google Search API request raises an exception for lookup
    When I lookup warranty info for product "Product" from merchant "Merchant"
    Then it should return nil
    And it should log a lookup exception

  # build_warranty_query method (tested through lookup_warranty_info)
  Scenario: Build query with product and merchant
    Given the Google Search API credentials are configured
    And the Google Search API returns valid warranty results
    When I lookup warranty info for product "MacBook Pro" from merchant "Apple"
    Then the search query should include "MacBook Pro"
    And the search query should include "Apple"
    And the search query should include "warranty length months"
    And the search query should include "manufacturer warranty return policy"

  Scenario: Build query with product only
    Given the Google Search API credentials are configured
    And the Google Search API returns valid warranty results
    When I lookup warranty info for product "iPhone" without merchant
    Then the search query should include "iPhone"
    And the search query should not include merchant name
    And the search query should include "warranty length months"

