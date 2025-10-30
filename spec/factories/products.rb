FactoryBot.define do
  factory :product do
    product_name { "Test Product" }
    merchant { "Amazon" }
    purchase_date { Date.today }
    warranty_months { 12 }
    issue_description { nil }
    gmail_uid { "test_user_123" }

    trait :expired do
      purchase_date { 2.years.ago }
      warranty_months { 12 }
    end

    trait :expiring_soon do
      purchase_date { 11.months.ago }
      warranty_months { 12 }
    end

    trait :long_warranty do
      warranty_months { 36 }
    end
  end
end
