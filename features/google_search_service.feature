Feature: Google Search Service
  As a system
  I want to search for warranty information
  So users can get warranty details

  Background:
    Given the Google Search API is configured

  Scenario: Lookup warranty info with valid product and merchant
    Given the Google Search API returns valid warranty results
    When I lookup warranty info for product "iPhone" from merchant "Apple" using Google Search using Google Search
    Then it should return warranty information
    And it should include warranty months
    And it should include return policy days
    And it should include source as "google_search"
    And it should include details array

  Scenario: Lookup warranty info without API credentials
    Given the Google Search API credentials are not configured
    When I lookup warranty info for product "iPhone" from merchant "Apple" using Google Search
    Then it should return nil

  Scenario: Lookup warranty info with empty search results
    Given the Google Search API returns empty results
    When I lookup warranty info for product "iPhone" from merchant "Apple" using Google Search
    Then it should return nil

  Scenario: Lookup warranty info without merchant
    Given the Google Search API returns valid warranty results
    When I lookup warranty info for product "iPhone" without merchant
    Then it should return warranty information

  Scenario: Build warranty query with merchant
    Given the Google Search API returns valid warranty results
    When I lookup warranty info for product "MacBook Pro" from merchant "Apple" using Google Search
    Then the search query should include the product name

  Scenario: Build warranty query without merchant
    Given the Google Search API returns valid warranty results
    When I lookup warranty info for product "MacBook Pro" without merchant
    Then the search query should include the product name

  Scenario: Perform search with successful response
    Given the Google Search API returns valid warranty results
    When I lookup warranty info for product "iPhone" from merchant "Apple" using Google Search
    Then it should return warranty information

  Scenario: Perform search with error response
    Given the Google Search API is configured
    And the Google Search API returns error status 500
    When I lookup warranty info for product "iPhone" from merchant "Apple" using Google Search
    Then it should return nil

  Scenario: Perform search with exception
    Given the Google Search API is configured
    And the Google Search API request fails
    When I lookup warranty info for product "iPhone" from merchant "Apple" using Google Search
    Then it should return nil

  Scenario: Extract warranty info with months pattern
    Given the Google Search API returns results with "12 months warranty"
    When I lookup warranty info for product "iPhone" from merchant "Apple" using Google Search
    Then it should extract warranty months as 12

  Scenario: Extract warranty info with year pattern
    Given the Google Search API returns results with "2 year warranty"
    When I lookup warranty info for product "iPhone" from merchant "Apple" using Google Search
    Then it should extract warranty months as 24

  Scenario: Extract warranty info with multiple warranty periods
    Given the Google Search API returns results with multiple warranty periods where first is higher
    When I lookup warranty info for product "iPhone" from merchant "Apple" using Google Search
    Then it should extract the highest warranty months

  Scenario: Extract return policy with days pattern
    Given the Google Search API returns results with "30 days return policy"
    When I lookup warranty info for product "iPhone" from merchant "Apple" using Google Search
    Then it should extract return policy days as 30

  Scenario: Extract return policy with multiple periods
    Given the Google Search API returns results with multiple return periods where first is higher
    When I lookup warranty info for product "iPhone" from merchant "Apple" using Google Search
    Then it should extract the highest return policy days

  Scenario: Extract warranty info without return policy
    Given the Google Search API returns results without return policy
    When I lookup warranty info for product "iPhone" from merchant "Apple" using Google Search
    Then it should default return policy days to 30

  Scenario: Extract warranty info without warranty information
    Given the Google Search API returns results without warranty information
    When I lookup warranty info for product "iPhone" from merchant "Apple" using Google Search
    Then it should return warranty information with nil warranty months
    And it should default return policy days to 30

  Scenario: Search warranty question with valid results
    Given the Google Search API returns valid search results
    When I search for warranty question "iPhone warranty coverage"
    Then it should return an array of search results
    And each result should have title, snippet, and url
    And the search query should include "iPhone warranty coverage"

  Scenario: Search warranty question without API credentials
    Given the Google Search API credentials are not configured
    When I search for warranty question "iPhone warranty coverage"
    Then it should return an empty array

  Scenario: Search warranty question with error response
    Given the Google Search API returns error status 500
    When I search for warranty question "iPhone warranty coverage"
    Then it should return an empty array

  Scenario: Search warranty question with exception
    Given the Google Search API request raises an exception
    When I search for warranty question "iPhone warranty coverage"
    Then it should return an empty array

  Scenario: Search warranty question with no items
    Given the Google Search API returns response with no items
    When I search for warranty question "iPhone warranty coverage"
    Then it should return an empty array
