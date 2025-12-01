Feature: Google Image Search Service
  As a system
  I want to search for product images and merchant logos
  So users can see visual representations of their products

  Background:
    Given the Google Image Search service is available

  Scenario: Service initializes without API credentials
    When I create a GoogleImageSearchService instance without credentials
    Then the image search service should be initialized without API key

  Scenario: Service initializes with API credentials
    Given the Google Search API credentials are configured
    When I create a GoogleImageSearchService instance
    Then the image search service should be initialized with API key and search engine ID

  Scenario: Service searches for product image successfully
    Given the Google Search API credentials are configured
    And the Google Image Search API returns valid product image results
    When I search for product image "iPhone 15" with merchant "Apple"
    Then it should return a valid image URL

  Scenario: Service searches for product image without merchant
    Given the Google Search API credentials are configured
    And the Google Image Search API returns valid product image results
    When I search for product image "MacBook Pro"
    Then it should return a valid image URL

  Scenario: Service returns nil when API credentials are missing
    When I search for product image "iPhone" with merchant "Apple"
    Then the image search should return nil

  Scenario: Service searches for merchant logo successfully
    Given the Google Search API credentials are configured
    And the Google Image Search API returns valid logo results
    When I search for merchant logo "Amazon"
    Then it should return a valid logo URL

  Scenario: Service returns nil for blank merchant
    Given the Google Search API credentials are configured
    When I search for merchant logo ""
    Then the image search should return nil

  Scenario: Service handles API errors gracefully
    Given the Google Search API credentials are configured
    And the Google Image Search API returns an error
    When I search for product image "iPhone" with merchant "Apple"
    Then the image search should return nil
    And the image search should log the error

