Feature: Product Model
  As a system
  I want to manage product warranty information
  So that users can track their warranties accurately

  Background:
    Given I have a signed in user

  Scenario: Calculate expiry date with purchase date and warranty months
    Given I have a product with purchase date "2024-01-15" and warranty "12" months
    When I calculate the expiry date
    Then it should return a date 12 months after purchase date

  Scenario: Product status is expired when past expiry date
    Given I have a product that expired 10 days ago
    When I check the product status
    Then it should return "expired"

  Scenario: Product status is active when more than 30 days remaining
    Given I have a product expiring in 60 days
    When I check the product status
    Then it should return "active"

  Scenario: Warranty is eligible when expiry date is in the future
    Given I have a product expiring in 60 days
    When I check if warranty is eligible
    Then it should return true

  Scenario: Expiry date returns nil when purchase date is missing
    Given I have a product without purchase date
    When I calculate the expiry date
    Then the expiry date should be nil

  Scenario: Expiry date returns nil when warranty months is missing
    Given I have a product without warranty months
    When I calculate the expiry date
    Then the expiry date should be nil

  Scenario: Days until expiry returns nil when expiry date is missing
    Given I have a product without expiry date
    When I calculate days until expiry
    Then the days until expiry should be nil

  Scenario: Product status is expiring soon when 30 days or less remaining
    Given I have a product expiring in 25 days
    When I check the product status
    Then it should return "expiring_soon"

  Scenario: Warranty eligibility check returns expired when warranty expired
    Given I have a product that expired 10 days ago
    And the AI service is stubbed to verify it is not called
    When I check warranty eligibility for issue "broken screen"
    Then it should return eligible false with reason "Warranty expired"
    And the AI service should not be called

  Scenario: Category icon returns furniture emoji for furniture products
    Given I have a product with name "Sofa" and merchant "Furniture Store"
    When I check the category icon
    Then the category icon should be "🏠"

  Scenario: Category icon returns cleaning emoji for vacuum products
    Given I have a product with name "Dyson Vacuum" and merchant "Best Buy"
    When I check the category icon
    Then the category icon should be "🧹"

  Scenario: Category icon returns hair emoji for hair products
    Given I have a product with name "Hair Dryer" and merchant "Ulta"
    When I check the category icon
    Then the category icon should be "💇"

  Scenario: Category icon returns makeup emoji for beauty products
    Given I have a product with name "Lipstick" and merchant "Sephora"
    When I check the category icon
    Then the category icon should be "💄"


  Scenario: Category icon returns watch emoji for watches
    Given I have a product with name "Apple Watch" and merchant "Apple"
    When I check the category icon
    Then the category icon should be "⌚"

  Scenario: Category icon returns game emoji for gaming products
    Given I have a product with name "PlayStation 5" and merchant "Best Buy"
    When I check the category icon
    Then the category icon should be "🎮"

  Scenario: Category icon returns toy emoji for toys
    Given I have a product with name "Doll" and merchant "Target"
    When I check the category icon
    Then the category icon should be "🧸"

  Scenario: Category icon returns book emoji for books
    Given I have a product with name "Kindle Book" and merchant "Amazon"
    When I check the category icon
    Then the category icon should be "📚"

  Scenario: Category icon returns tool emoji for tools
    Given I have a product with name "Drill" and merchant "Home Depot"
    When I check the category icon
    Then the category icon should be "🔨"

  Scenario: Category icon returns laundry emoji for washers
    Given I have a product with name "Washing Machine" and merchant "Home Depot"
    When I check the category icon
    Then the category icon should be "🌀"

  Scenario: Category icon returns kitchen emoji for kitchen appliances
    Given I have a product with name "Refrigerator" and merchant "Best Buy"
    When I check the category icon
    Then the category icon should be "🔥"

  Scenario: Category icon returns camera emoji for cameras
    Given I have a product with name "DSLR Camera" and merchant "B&H"
    When I check the category icon
    Then the category icon should be "📷"
