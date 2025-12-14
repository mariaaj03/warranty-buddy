Feature: Google Vision Service
  As a system
  I want to extract text from images
  So users can process receipt images

  Background:
    Given the Vision API is configured

  Scenario: System extracts text from image successfully
    When I extract text from an image
    Then it should return extracted text

  Scenario: System extracts text from PDF successfully
    When I extract text from a PDF
    Then it should return extracted text

  # Coverage scenarios for OAuth authorization setup
  Scenario: Service sets up OAuth authorization with expired tokens
    Given the Vision API key is not configured
    And the user has OAuth credentials with expired tokens
    When I create a Vision service instance
    Then it should set up OAuth authorization
    And it should refresh the OAuth tokens

  Scenario: Service sets up OAuth authorization with nil expires_at
    Given the Vision API key is not configured
    And the user has OAuth credentials with nil expires_at
    When I create a Vision service instance
    Then it should set up OAuth authorization
    And it should refresh the OAuth tokens

  Scenario: Service sets up OAuth authorization with past expires_at
    Given the Vision API key is not configured
    And the user has OAuth credentials with past expires_at
    When I create a Vision service instance
    Then it should set up OAuth authorization
    And it should refresh the OAuth tokens

  Scenario: Service skips OAuth setup when client credentials are missing
    Given the Vision API key is not configured
    And the user has OAuth tokens but no client credentials
    When I create a Vision service instance
    Then it should not set up OAuth authorization

  Scenario: Service handles OAuth refresh failure gracefully
    Given the Vision API key is not configured
    And the user has OAuth credentials with expired tokens
    And OAuth token refresh will fail
    When I create a Vision service instance

  Scenario: Service extracts text from scanned PDF using OCR
    Given the Vision API is configured
    And I have a scanned PDF with no extractable text
    When I extract text from a scanned PDF
    Then it should return extracted text from OCR

  Scenario: Service processes scanned PDF with multiple pages
    Given the Vision API is configured
    And I have a scanned PDF with multiple pages
    When I extract text from a scanned PDF
    Then it should process all pages
    And it should return extracted text from OCR
