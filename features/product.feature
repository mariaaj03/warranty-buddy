Feature: Product Model
  As a system
  I want to manage product warranty information
  So that users can track their warranties accurately

  Background:
    Given I have a signed in user

  # expiry_date method
  Scenario: Calculate expiry date with purchase date and warranty months
    Given I have a product with purchase date "2024-01-15" and warranty "12" months
    When I calculate the expiry date
    Then it should return a date 12 months after purchase date

  Scenario: Expiry date returns nil when purchase date is missing
    Given I have a product without purchase date
    When I calculate the expiry date
    Then it should return nil

  Scenario: Expiry date returns nil when warranty months is missing
    Given I have a product without warranty months
    When I calculate the expiry date
    Then it should return nil

  # days_until_expiry method
  Scenario: Calculate days until expiry for active warranty
    Given I have a product expiring in 60 days
    When I calculate days until expiry
    Then it should return 60 days

  Scenario: Days until expiry returns nil when expiry date is nil
    Given I have a product without expiry date
    When I calculate days until expiry
    Then it should return nil

  # status method
  Scenario: Product status is expired when past expiry date
    Given I have a product that expired 10 days ago
    When I check the product status
    Then it should return "expired"

  Scenario: Product status is expiring soon when within 30 days
    Given I have a product expiring in 15 days
    When I check the product status
    Then it should return "expiring_soon"

  Scenario: Product status is active when more than 30 days remaining
    Given I have a product expiring in 60 days
    When I check the product status
    Then it should return "active"

  # warranty_eligible? method
  Scenario: Warranty is eligible when expiry date is in the future
    Given I have a product expiring in 60 days
    When I check if warranty is eligible
    Then it should return true

  Scenario: Warranty is not eligible when expiry date is in the past
    Given I have a product that expired 10 days ago
    When I check if warranty is eligible
    Then it should return false

  Scenario: Warranty is not eligible when expiry date is nil
    Given I have a product without expiry date
    When I check if warranty is eligible
    Then it should return false

  Scenario: Warranty is eligible when expiry date is today
    Given I have a product expiring today
    When I check if warranty is eligible
    Then it should return true

  # check_warranty_eligibility method
  Scenario: Check warranty eligibility returns expired when warranty expired
    Given I have a product that expired 10 days ago
    And the AI service is stubbed to verify it is not called
    When I check warranty eligibility for issue "broken screen"
    Then it should return eligible false with reason "Warranty expired"
    And the AI service should not be called

  Scenario: Check warranty eligibility calls AI service when warranty is active
    Given I have an active product
    And the AI service is configured
    When I check warranty eligibility for issue "broken screen"
    Then it should call the AI service
    And it should pass the product name and issue description
    And it should use "Standard" warranty type when warranty_type is nil

  Scenario: Check warranty eligibility uses custom warranty type
    Given I have an active product with warranty type "Extended"
    And the AI service is configured
    When I check warranty eligibility for issue "water damage"
    Then it should call the AI service
    And it should use "Extended" warranty type in warranty terms

