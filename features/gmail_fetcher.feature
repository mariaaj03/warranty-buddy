Feature: Gmail Fetcher
  As a system
  I want to fetch and parse Gmail messages
  So that I can extract receipt information from emails

  Background:
    Given the Gmail Fetcher service is available

  Scenario: System initializes with access token only
    Given I have an access token
    When I create a Gmail Fetcher with access token only
    Then it should be initialized

  Scenario: System initializes with refresh token and user
    Given I have an access token and refresh token
    And I have a user
    When I create a Gmail Fetcher with refresh token
    Then it should be initialized

  Scenario: System refreshes expired credentials
    Given I have expired credentials
    When I create a Gmail Fetcher with refresh token
    Then it should refresh the credentials
    And it should update the user tokens

  Scenario: System handles credential refresh failure
    Given I have expired credentials
    And credential refresh will fail
    When I create a Gmail Fetcher with refresh token
    Then it should handle refresh failure gracefully

  Scenario: System skips refresh when credentials are valid
    Given I have valid credentials
    When I create a Gmail Fetcher with refresh token
    Then it should not refresh the credentials

  Scenario: System skips refresh when client credentials are missing
    Given I have expired credentials
    And client credentials are missing
    When I create a Gmail Fetcher with refresh token
    Then it should not set up refresh authorization

  Scenario: System extracts HTML from message body
    Given I have a message with HTML in body
    When I extract HTML from the message
    Then it should return the HTML content

  Scenario: System extracts HTML from message parts
    Given I have a message with HTML in parts
    When I extract HTML from the message
    Then it should return the HTML content

  Scenario: System returns empty string when no HTML found
    Given I have a message with no HTML
    When I extract HTML from the message
    Then it should return an empty string

  Scenario: System extracts text from message body
    Given I have a message with text in body
    When I extract text from the message
    Then it should return the text content

  Scenario: System extracts text from message parts
    Given I have a message with text in parts
    When I extract text from the message
    Then it should return the text content

  Scenario: System returns empty string when no text found
    Given I have a message with no text
    When I extract text from the message
    Then it should return an empty string

  Scenario: System extracts attachments from message parts
    Given I have a message with attachments in parts
    When I extract attachments from the message
    Then it should return the attachments

  Scenario: System extracts attachments from nested parts
    Given I have a message with attachments in nested parts
    When I extract attachments from the message
    Then it should return all attachments

  Scenario: System returns empty array when no attachments
    Given I have a message with no attachments
    When I extract attachments from the message
    Then it should return an empty array

  Scenario: System handles message with no payload parts
    Given I have a message with no payload parts
    When I extract attachments from the message
    Then it should return an empty array

  Scenario: System decodes base64 with URL-safe encoding
    Given I have URL-safe base64 encoded data
    When I decode the base64 data
    Then it should return decoded content

  Scenario: System falls back to standard base64 decoding
    Given I have standard base64 encoded data
    When I decode the base64 data
    Then it should return decoded content

  Scenario: System handles base64 decoding errors
    Given I have invalid base64 data
    When I decode the base64 data
    Then it should handle the error gracefully

  Scenario: System lists messages with pagination
    Given the Gmail API returns paginated messages
    When I list messages with query "test"
    Then it should return all messages from all pages

  Scenario: System limits message results
    Given the Gmail API returns many messages
    When I list messages with max results 10
    Then it should return at most 10 messages

  Scenario: System gets full message by ID
    Given I have a message ID
    When I get the message
    Then it should return the full message

  Scenario: System skips HTML body that doesn't contain html tag
    Given I have a message with HTML body without html tag
    When I extract HTML from the message
    Then it should search in parts

  Scenario: System skips text body that contains html tag
    Given I have a message with text body containing html tag
    When I extract text from the message
    Then it should search in parts

  Scenario: System handles nested parts recursively for HTML
    Given I have a message with HTML in deeply nested parts
    When I extract HTML from the message
    Then it should return the HTML content

  Scenario: System handles nested parts recursively for text
    Given I have a message with text in deeply nested parts
    When I extract text from the message
    Then it should return the text content

