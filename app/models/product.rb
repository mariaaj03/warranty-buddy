class Product < ApplicationRecord
  validates :product_name, presence: true
  validates :warranty_months, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :gmail_uid, presence: true

  scope :active, -> { where("(purchase_date + INTERVAL '1 month' * warranty_months) >= ?", Date.current) }
  scope :expired, -> { where("(purchase_date + INTERVAL '1 month' * warranty_months) < ?", Date.current) }
  scope :expiring_soon, -> { where("(purchase_date + INTERVAL '1 month' * warranty_months) BETWEEN ? AND ?", Date.current, 30.days.from_now) }
  scope :by_merchant, ->(merchant) { where(merchant: merchant) }
  scope :search, ->(term) { where("product_name ILIKE ? OR merchant ILIKE ?", "%#{term}%", "%#{term}%") }
  scope :for_user, ->(gmail_uid) { where(gmail_uid: gmail_uid) }

  def expiry_date
    return nil unless purchase_date && warranty_months
    (purchase_date.to_date >> warranty_months) # add months
  end

  def days_until_expiry
    return nil unless expiry_date
    (expiry_date - Date.current).to_i
  end

  def status
    return "expired" if expiry_date && expiry_date < Date.current
    return "expiring_soon" if days_until_expiry && days_until_expiry <= 30
    "active"
  end

  def warranty_eligible?
    return false unless expiry_date
    expiry_date >= Date.current
  end

  def check_warranty_eligibility(issue_description)
    return { eligible: false, reason: "Warranty expired" } unless warranty_eligible?

    ai_service = AiService.new
    warranty_terms = "#{warranty_type || 'Standard'} warranty for #{product_name}"

    ai_service.check_warranty_eligibility(product_name, issue_description, warranty_terms)
  end
end
