Feature: AI Service
  As a system
  I want to interact with Google Gemini API
  So that I can extract receipt information and answer warranty questions

  Background:
    Given the Gemini API key is configured

  # extract_retry_delay method
  Scenario: System extracts retry delay from error data with valid delay string
    Given I have error data with RetryInfo and delay "5s"
    When I extract the retry delay
    Then it should return 5.0 seconds

  Scenario: System extracts retry delay from error data with delay without 's'
    Given I have error data with RetryInfo and delay "10"
    When I extract the retry delay
    Then it should return 10.0 seconds

  Scenario: System extracts retry delay from error data with decimal delay
    Given I have error data with RetryInfo and delay "2.5s"
    When I extract the retry delay
    Then it should return 2.5 seconds

  Scenario: System returns nil for zero delay
    Given I have error data with RetryInfo and delay "0s"
    When I extract the retry delay
    Then it should return nil

  Scenario: System returns nil for invalid delay format
    Given I have error data with RetryInfo and delay "invalid"
    When I extract the retry delay
    Then it should return nil

  Scenario: System returns nil when RetryInfo has no delay
    Given I have error data with RetryInfo but no delay
    When I extract the retry delay
    Then it should return nil

  Scenario: System returns nil when error data has no RetryInfo
    Given I have error data without RetryInfo
    When I extract the retry delay
    Then it should return nil

  Scenario: System returns nil for empty error data
    Given I have empty error data
    When I extract the retry delay
    Then it should return nil

  # call_gemini_api method
  Scenario: System successfully calls Gemini API
    Given the Gemini API returns status 200 with valid response
    When I call the Gemini API with prompt "test prompt"
    Then it should return the response text

  Scenario: System handles empty text response
    Given the Gemini API returns status 200 with empty text
    When I call the Gemini API with prompt "test prompt"
    Then it should return an empty string

  Scenario: System retries on rate limit with valid retry delay
    Given the Gemini API returns status 429 with retry delay of 5 seconds
    And the retry count is 0
    When I call the Gemini API with prompt "test prompt"
    Then it should retry the API call
    And it should return the response text

  Scenario: System raises error when retry count exceeds limit
    Given the Gemini API returns status 429 with retry delay of 5 seconds
    And the retry count is 2
    When I call the Gemini API with prompt "test prompt"
    Then it should raise GeminiRateLimitError
    And the error should include retry delay

  Scenario: System raises error when retry delay exceeds max
    Given the Gemini API returns status 429 with retry delay of 15 seconds
    And the retry count is 0
    When I call the Gemini API with prompt "test prompt"
    Then it should raise GeminiRateLimitError

  Scenario: System raises error when retry delay is zero
    Given the Gemini API returns status 429 with retry delay of 0 seconds
    And the retry count is 0
    When I call the Gemini API with prompt "test prompt"
    Then it should raise GeminiRateLimitError

  Scenario: System handles rate limit without retry delay
    Given the Gemini API returns status 429 without retry delay
    When I call the Gemini API with prompt "test prompt"
    Then it should raise GeminiRateLimitError
    And the error should not include retry delay

  Scenario: System handles non-429 error codes
    Given the Gemini API returns status 500 with error message
    When I call the Gemini API with prompt "test prompt"
    Then it should raise an error with message containing "API error"

  Scenario: System handles invalid JSON response
    Given the Gemini API returns invalid JSON
    When I call the Gemini API with prompt "test prompt"
    Then it should raise an error with message "Gemini API error: Invalid response format"

  # call_gemini_api_with_image method
  Scenario: System successfully calls Gemini API with image
    Given the Gemini API returns status 200 with valid response
    When I call the Gemini API with image and prompt "test prompt"
    Then it should return the response text

  Scenario: System retries on rate limit with image
    Given the Gemini API returns status 429 with retry delay of 5 seconds
    And the retry count is 0
    When I call the Gemini API with image and prompt "test prompt"
    Then it should retry the API call
    And it should return the response text

  Scenario: System raises error when retry count exceeds limit with image
    Given the Gemini API returns status 429 with retry delay of 5 seconds
    And the retry count is 2
    When I call the Gemini API with image and prompt "test prompt"
    Then it should raise GeminiRateLimitError

  Scenario: System handles non-429 error codes with image
    Given the Gemini API returns status 500 with error message
    When I call the Gemini API with image and prompt "test prompt"
    Then it should raise an error with message containing "API error"

  # answer_warranty_question method
  Scenario: System builds search context when search results exist
    Given I have search results
    When I answer warranty question "test question" with search results
    Then it should include search context in the prompt

  Scenario: System skips search context when no search results
    Given I have no search results
    When I answer warranty question "test question" without search results
    Then it should not include search context

  Scenario: System returns fallback message when response is blank
    Given the Gemini API returns status 200 with empty text
    When I answer warranty question "test question" without search results
    Then it should return the fallback message

  # extract_receipt_info method
  Scenario: System returns receipt data when AI confirms receipt
    Given the Gemini API returns receipt confirmation
    When I extract receipt info from email content
    Then it should return receipt data

  Scenario: System returns nil when AI determines not a receipt
    Given the Gemini API returns non-receipt confirmation
    When I extract receipt info from email content
    Then it should return nil

  Scenario: System handles JSON parsing errors in extract_receipt_info
    Given the Gemini API returns invalid JSON
    When I extract receipt info from email content
    Then it should return nil

  # extract_receipt_info_from_image method
  Scenario: System returns receipt data from image when AI confirms receipt
    Given the Gemini API returns receipt confirmation
    When I extract receipt info from image
    Then it should return receipt data

  Scenario: System returns nil from image when AI determines not a receipt
    Given the Gemini API returns non-receipt confirmation
    When I extract receipt info from image
    Then it should return nil

  Scenario: System handles retry when delay is negative
    Given the Gemini API returns status 429 with retry delay of -5 seconds
    And the retry count is 0
    When I call the Gemini API with prompt "test prompt"
    Then it should raise GeminiRateLimitError

  Scenario: System handles retry when delay exceeds max retry delay
    Given the Gemini API returns status 429 with retry delay of 15 seconds
    And the retry count is 0
    When I call the Gemini API with prompt "test prompt"
    Then it should raise GeminiRateLimitError

  Scenario: System handles retry when retry count is at limit
    Given the Gemini API returns status 429 with retry delay of 5 seconds
    And the retry count is 1
    When I call the Gemini API with prompt "test prompt"
    Then it should raise GeminiRateLimitError

  Scenario: System handles retry with image when delay exceeds max
    Given the Gemini API returns status 429 with retry delay of 15 seconds
    And the retry count is 0
    When I call the Gemini API with image and prompt "test prompt"
    Then it should raise GeminiRateLimitError

  Scenario: System handles retry with image when retry count is at limit
    Given the Gemini API returns status 429 with retry delay of 5 seconds
    And the retry count is 1
    When I call the Gemini API with image and prompt "test prompt"
    Then it should raise GeminiRateLimitError
