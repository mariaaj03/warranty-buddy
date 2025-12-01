Feature: Chatbot Controller
  As a user
  I want to ask warranty questions to a chatbot
  So that I can get answers about warranty information

  Background:
    Given I am a signed in user

  Scenario: User asks a valid warranty question
    Given the AI service is configured
    When I send a POST request to "/chatbot/ask" with question "What is the warranty period for laptops?"
    Then I should receive a JSON response with status 200
    And the response should contain an "answer" field

  Scenario: User asks question with blank input
    When I send a POST request to "/chatbot/ask" with question ""
    Then I should receive a JSON response with status 400

  Scenario: User asks question when AI service is not configured
    Given the AI service is not configured
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should receive a JSON response with status 503

  Scenario: User asks question with whitespace that gets stripped
    Given the AI service is configured
    And the Google Search service is available
    When I send a POST request to "/chatbot/ask" with question "  What is warranty?  "
    Then I should receive a JSON response with status 200
    And the response should contain an "answer" field

  Scenario: Web search service fails and logs warning
    Given the AI service is configured
    And the Google Search service raises an exception
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should receive a JSON response with status 200
    And it should log a warning about web search being unavailable
    And the response should contain an "answer" field

  Scenario: AI service returns nil answer
    Given the AI service is configured but returns nil
    And the Google Search service is available
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should receive a JSON response with status 500
    And the response should contain error about unable to generate answer

  Scenario: AI service raises rate limit error
    Given the AI service raises a rate limit error
    And the Google Search service is available
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should receive a JSON response with status 429
    And the response should contain error about rate limiting
    And it should log a rate limit error

  Scenario: AI service raises generic error with rate limit keywords
    Given the AI service raises an error with rate limit keywords
    And the Google Search service is available
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should receive a JSON response with status 500
    And it should log the error message
    And it should log the error backtrace
    And the error message should include "rate-limited"

  Scenario: AI service raises generic error without rate limit keywords
    Given the AI service raises a generic error
    And the Google Search service is available
    When I send a POST request to "/chatbot/ask" with question "What is warranty?"
    Then I should receive a JSON response with status 500
    And it should log the error message
    And it should log the error backtrace
    And the error message should include "An error occurred"
