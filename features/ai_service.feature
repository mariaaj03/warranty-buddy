Feature: AI Service
  As a system
  I want to interact with the Gemini API
  So I can extract receipt information and answer warranty questions

  Background:
    Given the Gemini API key is configured

  Scenario: System calls Gemini API successfully
    Given the Gemini API returns status 200 with valid response
    When I call the Gemini API with prompt "test prompt"
    Then it should return the response text

  Scenario: System handles 429 rate limit error in call_gemini_api
    Given the Gemini API returns status 429 without retry delay
    When I call the Gemini API with prompt "test prompt"
    Then it should raise GeminiRateLimitError

  Scenario: System handles other error codes in call_gemini_api
    Given the Gemini API returns status 500 with error message
    When I call the Gemini API with prompt "test prompt"
    Then it should raise an error with message containing "Gemini API error: 500"

  Scenario: System handles 429 rate limit error in call_gemini_api_with_image
    Given the Gemini API returns status 429 without retry delay
    When I call the Gemini API with image and prompt "test prompt"
    Then it should raise GeminiRateLimitError

  Scenario: System handles other error codes in call_gemini_api_with_image
    Given the Gemini API returns status 500 with error message
    When I call the Gemini API with image and prompt "test prompt"
    Then it should raise an error with message containing "Gemini API error: 500"

  Scenario: System handles invalid JSON response
    Given the Gemini API returns invalid JSON
    When I call the Gemini API with prompt "test prompt"
    Then it should raise an error with message containing "Invalid response format"

  Scenario: System answers warranty question with search results
    Given I have search results
    When I answer warranty question "test question" with search results
    Then it should include search context in the prompt

  Scenario: System answers warranty question without search results
    Given I have no search results
    When I answer warranty question "test question" without search results
    Then it should not include search context


  Scenario: System extracts receipt info with markdown cleanup
    Given the Gemini API returns receipt confirmation with markdown
    When I extract receipt info from email content
    Then it should return receipt data

  Scenario: System extracts receipt info from image with markdown cleanup
    Given the Gemini API returns receipt confirmation with markdown
    When I extract receipt info from image
    Then it should return receipt data

  # Coverage scenarios for initialization and error handling
  Scenario: Service initializes with client parameter
    When I create an AI service with a client
    Then the service should use the provided client
    And the API key should be nil

  Scenario: Service initializes without API key
    Given the Gemini API key is not configured
    When I create an AI service without API key
    Then the service should log an error about missing API key
    And the client should be nil

  Scenario: Service handles JSON parsing error in lookup_warranty_info
    Given the Gemini API returns invalid JSON for warranty lookup
    When I lookup warranty info for "iPhone 15" from "Apple"
    Then it should return nil

  Scenario: Service handles JSON parsing error in check_warranty_eligibility
    Given the Gemini API returns invalid JSON for warranty eligibility
    When I check warranty eligibility for "iPhone 15" with issue "screen cracked"
    Then it should return nil
