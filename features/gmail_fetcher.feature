Feature: Gmail Fetcher
  As a system
  I want to fetch Gmail messages
  So I can process receipt emails

  Background:
    Given I have Gmail credentials

  Scenario: System lists messages successfully
    When I list Gmail messages
    Then it should return message list

  # Coverage scenarios for extract_html_from_message
  Scenario: Extract HTML from message with HTML in body data
    Given I have a message with HTML in body data
    When I extract HTML from the message
    Then the Gmail fetcher should return the HTML content from body

  Scenario: Extract HTML from message with body data that is not HTML
    Given I have a message with body data that is not HTML
    And the Gmail message has HTML parts
    When I extract HTML from the message
    Then the Gmail fetcher should return the HTML content from parts

  Scenario: Extract HTML from message with parts but no body data
    Given I have a Gmail message with HTML in parts but no body data
    When I extract HTML from the message
    Then the Gmail fetcher should return the HTML content from parts

  # Coverage scenarios for extract_text_from_message and find_text_part
  Scenario: Extract text from message with text in nested parts
    Given I have a message with text in nested parts
    When I extract text from the message
    Then it should return the text content from nested parts

  Scenario: Extract text from message with text part that has no body data
    Given I have a message with text part but no body data
    When I extract text from the message
    Then it should return an empty string

  # Coverage scenarios for extract_attachments
  Scenario: Extract attachments from message with attachment in nested parts
    Given I have a message with attachment in nested parts
    When I extract attachments from the message
    Then it should return all attachments including nested ones
