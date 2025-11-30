class Product < ApplicationRecord
  belongs_to :user

  validates :product_name, presence: true
  validates :warranty_months, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :active, -> { where("(purchase_date + INTERVAL '1 month' * warranty_months) >= ?", Date.current) }
  scope :expired, -> { where("(purchase_date + INTERVAL '1 month' * warranty_months) < ?", Date.current) }
  scope :expiring_soon, -> { where("(purchase_date + INTERVAL '1 month' * warranty_months) BETWEEN ? AND ?", Date.current, 30.days.from_now) }
  scope :by_merchant, ->(merchant) { where(merchant: merchant) }
  scope :search, ->(term) { where("product_name ILIKE ? OR merchant ILIKE ?", "%#{term}%", "%#{term}%") }

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

  def category_icon
    # Icon based on product category and merchant
    name_lower = product_name.downcase
    merchant_lower = merchant.to_s.downcase
    
    # Apple iPhone specific
    if merchant_lower.include?("apple") && (name_lower.include?("iphone") || name_lower.include?("phone"))
      return "📱"
    end
    
    # Beauty & Cosmetics
    if name_lower.match?(/makeup|cosmetic|lipstick|mascara|foundation|concealer|blush|eyeshadow|nail polish|perfume|fragrance|bath.*body|body.*scrub|body.*wash|soap|shampoo|conditioner|hair.*product|hair.*care|hair.*treatment|serum|moisturizer|cleanser|toner|essence|mask|skincare|beauty/)
      return "💄"
    end
    
    # Hair products
    if name_lower.match?(/hair|shampoo|conditioner|hair.*spray|hair.*gel|hair.*oil|hair.*serum|hair.*mask|hair.*treatment|hair.*brush|hair.*dryer|flat.*iron|curling.*iron/)
      return "💇"
    end
    
    # Feminine products
    if name_lower.match?(/tampon|pad|panty|lingerie|bra|underwear|intimate|feminine|pink|victoria.*secret|pink.*new/)
      return "🌸"
    end
    
    # Cleaning & Vacuum
    if name_lower.match?(/vacuum|cleaner|dyson|dirt|dust|mop|broom|cleaning|detergent|bleach|disinfectant/)
      return "🧹"
    end
    
    # Housing & Home items
    if name_lower.match?(/furniture|sofa|couch|chair|table|bed|mattress|pillow|blanket|curtain|rug|carpet|decor|home|household|kitchen.*ware|dinnerware|plate|bowl|cup|mug|glass/)
      return "🏠"
    end
    
    # Electronics - Phones
    if name_lower.match?(/phone|iphone|samsung|pixel|android|mobile|smartphone/)
      return "📱"
    end
    
    # Electronics - Computers
    if name_lower.match?(/laptop|macbook|computer|pc|desktop|imac|mac.*mini/)
      return "💻"
    end
    
    # Electronics - Tablets
    if name_lower.match?(/tablet|ipad/)
      return "📱"
    end
    
    # Electronics - TVs
    if name_lower.match?(/tv|television|monitor|display|screen/)
      return "📺"
    end
    
    # Electronics - Audio
    if name_lower.match?(/headphones|earbuds|earphones|airpods|speaker|soundbar|audio|headset/)
      return "🎧"
    end
    
    # Electronics - Watches
    if name_lower.match?(/watch|apple.*watch|smartwatch|fitbit/)
      return "⌚"
    end
    
    # Electronics - Cameras
    if name_lower.match?(/camera|dslr|mirrorless|gopro/)
      return "📷"
    end
    
    # Gaming
    if name_lower.match?(/game|playstation|xbox|nintendo|console|controller/)
      return "🎮"
    end
    
    # Appliances - Kitchen
    if name_lower.match?(/refrigerator|fridge|freezer|oven|microwave|stove|range|dishwasher|coffee.*maker|blender|mixer|toaster/)
      return "🔥"
    end
    
    # Appliances - Laundry
    if name_lower.match?(/washer|dryer|washing|laundry/)
      return "🌀"
    end
    
    # Tools
    if name_lower.match?(/tool|drill|saw|hammer|screwdriver|wrench/)
      return "🔨"
    end
    
    # Clothing
    if name_lower.match?(/clothing|shirt|pants|shoes|jacket|dress|sweater|hoodie|jeans/)
      return "👕"
    end
    
    # Books
    if name_lower.match?(/book|kindle|ebook/)
      return "📚"
    end
    
    # Toys
    if name_lower.match?(/toy|doll|game.*toy/)
      return "🧸"
    end
    
    # Default
    "📦"
  end
end
