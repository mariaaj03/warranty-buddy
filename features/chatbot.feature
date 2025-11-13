Feature: Chatbot Controller
  As a user
  I want to ask warranty questions to a chatbot
  So that I can get answers about warranty information

  Background:
    Given I am a signed in user

  Scenario: User asks a valid warranty question
    Given the AI service is configured
    And the Google Search service is available
    When I send a POST request to "/chatbot/ask" with question "What is the warranty period for laptops?"
    Then I should receive a JSON response with status 200
    And the response should contain an "answer" field
    And the response should contain a "sources" field

  Scenario: User asks question with whitespace that gets stripped
    Given the AI service is configured
    And the Google Search service is available
    When I send a POST request to "/chatbot/ask" with question "  What is warranty?  "
    Then I should receive a JSON response with status 200
    And the response should contain an "answer" field

  Scenario: User asks question with blank input
    When I send a POST request to "/chatbot/ask" with question ""
    Then I should receive a JSON response with status 400
    And the response should contain error "Please provide a question"

  Scenario: User asks question with whitespace-only input
    When I send a POST request to "/chatbot/ask" with question "   "
    Then I should receive a JSON response with status 400
    And the response should contain error "Please provide a question"

  Scenario: User asks question without providing question parameter
    When I send a POST request to "/chatbot/ask" without question parameter
    Then I should receive a JSON response with status 400
    And the response should contain error "Please provide a question"

  Scenario: User asks question when AI service is not configured
    Given the AI service is not configured
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should receive a JSON response with status 503
    And the response should contain error about chatbot not being configured

  Scenario: User asks question when Google Search service fails but continues
    Given the AI service is configured
    And the Google Search service raises an exception
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should receive a JSON response with status 200
    And the response should contain an "answer" field
    And it should log a warning about web search being unavailable
    And the response should contain an empty "sources" array

  Scenario: User asks question when Google Search service returns nil
    Given the AI service is configured
    And the Google Search service returns nil
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should receive a JSON response with status 200
    And the response should contain an "answer" field
    And the response should contain an empty "sources" array

  Scenario: User asks question with more than 3 search results
    Given the AI service is configured
    And the Google Search service returns 5 results
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should receive a JSON response with status 200
    And the response should contain an "answer" field
    And the response should contain a "sources" field with at most 3 items

  Scenario: User asks question when AI service fails to generate answer
    Given the AI service is configured but returns nil
    And the Google Search service is available
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should receive a JSON response with status 500
    And the response should contain error about unable to generate answer

  Scenario: User asks question when rate limit error occurs with retry delay
    Given the AI service is configured
    And the AI service raises a rate limit error with retry delay of 60 seconds
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should receive a JSON response with status 429
    And the response should contain error about rate limiting
    And the error message should include retry delay information
    And it should log a rate limit error

  Scenario: User asks question when rate limit error occurs without retry delay
    Given the AI service is configured
    And the AI service raises a rate limit error without retry delay
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should receive a JSON response with status 429
    And the response should contain error about rate limiting
    And the error message should not include retry delay information
    And it should log a rate limit error

  Scenario: User asks question when generic error occurs
    Given the AI service is configured
    And the AI service raises a generic error
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should receive a JSON response with status 500
    And the response should contain an error message
    And it should log the error message
    And it should log the error backtrace

  Scenario: User asks question when error contains 429 status code
    Given the AI service is configured
    And the AI service raises an error with message containing "429"
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should receive a JSON response with status 500
    And the response should contain error about rate limiting

  Scenario: User asks question when error contains rate limit keywords
    Given the AI service is configured
    And the AI service raises an error with message containing "rate limit"
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should receive a JSON response with status 500
    And the response should contain error about rate limiting

  Scenario: User asks question when error contains quota keywords
    Given the AI service is configured
    And the AI service raises an error with message containing "quota"
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should receive a JSON response with status 500
    And the response should contain error about rate limiting

  Scenario: Unauthenticated user tries to ask question
    Given I am not signed in
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should be redirected to sign in

  Scenario: User asks question when AI service is configured with client
    Given the AI service is configured with client present
    And the Google Search service is available
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should receive a JSON response with status 200
    And the response should contain an "answer" field

  Scenario: User asks question when rate limit error occurs during initialization
    Given the AI service raises a rate limit error during initialization with retry delay of 30 seconds
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should receive a JSON response with status 429
    And the response should contain error about rate limiting
    And the error message should include retry delay information
    And it should log a rate limit error

  Scenario: User asks question when rate limit error occurs during initialization without retry delay
    Given the AI service raises a rate limit error during initialization without retry delay
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should receive a JSON response with status 429
    And the response should contain error about rate limiting
    And the error message should not include retry delay information
    And it should log a rate limit error

  Scenario: User asks question when generic error occurs during initialization with 429 message
    Given the AI service raises a generic error during initialization with message containing "429"
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should receive a JSON response with status 500
    And the response should contain error about rate limiting
    And it should log the error message
    And it should log the error backtrace

  Scenario: User asks question when generic error occurs during initialization with rate limit message
    Given the AI service raises a generic error during initialization with message containing "rate limit"
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should receive a JSON response with status 500
    And the response should contain error about rate limiting
    And it should log the error message
    And it should log the error backtrace

  Scenario: User asks question when generic error occurs during initialization with quota message
    Given the AI service raises a generic error during initialization with message containing "quota"
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should receive a JSON response with status 500
    And the response should contain error about rate limiting
    And it should log the error message
    And it should log the error backtrace

  Scenario: User asks question when generic error occurs during initialization with other message
    Given the AI service raises a generic error during initialization with message "Connection failed"
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should receive a JSON response with status 500
    And the response should contain an error message
    And the error message should include "Connection failed"
    And it should log the error message
    And it should log the error backtrace

