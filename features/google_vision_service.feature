Feature: Google Vision Service
  As a system
  I want to extract text from images and PDFs using Google Vision API
  So that I can process receipt images for warranty information

  Background:
    Given the Vision API service is available

  Scenario: System extracts text from image with API key
    Given the Vision API key is configured
    When I extract text from an image with API key
    Then it should return extracted text

  Scenario: System returns nil when Vision API key is not configured
    Given the Vision API key is not configured
    And the user does not have OAuth credentials
    When I extract text from an image
    Then it should return nil

  Scenario: System extracts text from image with OAuth credentials
    Given the Vision API key is not configured
    And the user has OAuth credentials
    When I extract text from an image with OAuth
    Then it should return extracted text

  Scenario: System handles Vision API error response
    Given the Vision API key is configured
    And the Vision API returns error status 400
    When I extract text from an image with API key
    Then it should return nil

  Scenario: System handles Vision API exception
    Given the Vision API key is configured
    And the Vision API request raises an exception
    When I extract text from an image with API key
    Then it should return nil

  Scenario: System extracts text from PDF successfully
    Given the PDF::Reader gem is available
    When I extract text from a PDF
    Then it should return extracted text

  Scenario: System handles PDF::Reader gem not available
    Given the PDF::Reader gem is not available
    When I extract text from a PDF
    Then it should return nil

  Scenario: System handles PDF processing errors
    Given the PDF::Reader gem is available
    And PDF processing will raise an error
    When I extract text from a PDF
    Then it should return nil

  Scenario: System sets up OAuth authorization when user has tokens
    Given the Vision API key is not configured
    And the user has OAuth credentials
    When I create a Vision service instance
    Then it should set up OAuth authorization

  Scenario: System sets up OAuth authorization with expired credentials
    Given the Vision API key is not configured
    And the user has OAuth credentials with expired tokens
    When I create a Vision service instance
    Then it should refresh the OAuth tokens

  Scenario: System handles OAuth token refresh failure
    Given the Vision API key is not configured
    And the user has OAuth credentials with expired tokens
    And OAuth token refresh will fail
    When I create a Vision service instance
    Then it should handle refresh failure gracefully

  Scenario: System skips OAuth setup when API key is present
    Given the Vision API key is configured
    When I create a Vision service instance
    Then it should not set up OAuth authorization

  Scenario: System skips OAuth setup when user has no tokens
    Given the Vision API key is not configured
    And the user does not have OAuth credentials
    When I create a Vision service instance
    Then it should not set up OAuth authorization

  Scenario: System skips OAuth setup when client credentials are missing
    Given the Vision API key is not configured
    And the user has OAuth tokens but no client credentials
    When I create a Vision service instance
    Then it should not set up OAuth authorization

  Scenario: System uses OAuth credentials when they are not expired
    Given the Vision API key is not configured
    And the user has OAuth credentials with valid tokens
    When I create a Vision service instance
    Then it should set up OAuth authorization
    And it should not refresh the tokens

