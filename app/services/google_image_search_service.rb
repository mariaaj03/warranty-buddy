require "net/http"
require "json"
require "uri"

class GoogleImageSearchService
  def initialize
    # Try search_api_key first, then fall back to other Google API keys
    @api_key = Rails.application.credentials.dig(:google, :search_api_key) || 
                Rails.application.credentials.dig(:google, :vision_api_key) ||
                Rails.application.credentials.dig(:google, :gemini_api_key) ||
                ENV["GOOGLE_SEARCH_API_KEY"] ||
                ENV["GOOGLE_VISION_API_KEY"] ||
                ENV["GOOGLE_GEMINI_API_KEY"]
    @search_engine_id = Rails.application.credentials.dig(:google, :search_engine_id) || ENV["GOOGLE_SEARCH_ENGINE_ID"]
  end

  def search_product_image(product_name, merchant = nil)
    return nil unless @api_key && @search_engine_id

    # Build search query
    query = build_image_query(product_name, merchant)
    
    # Perform image search
    image_url = perform_image_search(query)
    
    # Validate image URL
    return nil unless image_url && valid_image_url?(image_url)
    
    image_url
  rescue => e
    Rails.logger.error "Google Image Search failed: #{e.message}"
    nil
  end

  def search_merchant_logo(merchant)
    return nil unless @api_key && @search_engine_id
    return nil if merchant.blank?

    # Build search query for merchant logo
    query = "#{merchant} logo"
    
    # Perform image search
    image_url = perform_image_search(query, logo: true)
    
    # Validate image URL
    return nil unless image_url && valid_image_url?(image_url)
    
    image_url
  rescue => e
    Rails.logger.error "Google Merchant Logo Search failed: #{e.message}"
    nil
  end

  private

  def build_image_query(product_name, merchant)
    # Build query: product name + merchant + "product image" or "product photo"
    query_parts = [product_name]
    query_parts << merchant if merchant.present?
    query_parts << "product image"
    
    query_parts.join(" ")
  end

  def perform_image_search(query, logo: false)
    uri = URI("https://www.googleapis.com/customsearch/v1")
    params = {
      key: @api_key,
      cx: @search_engine_id,
      q: query,
      searchType: "image",
      num: 3, # Get top 3 results, we'll pick the best one
      safe: "active", # Safe search
    }
    
    if logo
      # For logos, prefer smaller square images
      params[:imgSize] = "small"
      params[:imgType] = "clipart" # Logos are often clipart/graphics
    else
      # For product photos, prefer medium-sized photos
      params[:imgSize] = "medium"
      params[:imgType] = "photo"
    end
    
    uri.query = URI.encode_www_form(params)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    # In development, allow self-signed certificates and skip CRL checks
    if Rails.env.development?
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)

    if response.code == "200"
      data = JSON.parse(response.body)
      items = data["items"]
      
      return nil unless items&.any?
      
      # Find the best image
      best_image = logo ? find_best_logo(items, query) : find_best_image(items, query)
      
      best_image&.dig("link")
    else
      Rails.logger.error "Google Image Search API error: #{response.code} - #{response.body}"
      nil
    end
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse Google Image Search response: #{e.message}"
    nil
  end

  def find_best_image(items, query)
    # Score images based on relevance
    scored_images = items.map do |item|
      score = 0
      title = (item["title"] || "").downcase
      snippet = (item["snippet"] || "").downcase
      link = item["link"] || ""
      
      # Prefer images with product-related keywords
      product_keywords = ["product", "photo", "image", "picture"]
      if product_keywords.any? { |kw| title.include?(kw) || snippet.include?(kw) }
        score += 10
      end
      
      # Avoid logos and icons
      avoid_keywords = ["logo", "icon", "badge", "button", "symbol"]
      if avoid_keywords.any? { |kw| title.include?(kw) || snippet.include?(kw) }
        score -= 20
      end
      
      # Prefer certain domains (product pages, retailers)
      preferred_domains = ["amazon.com", "bestbuy.com", "target.com", "walmart.com", 
                          "apple.com", "samsung.com", "sony.com"]
      if preferred_domains.any? { |domain| link.include?(domain) }
        score += 15
      end
      
      # Prefer larger images (check image dimensions if available)
      width = item["image"]&.dig("width") || 0
      height = item["image"]&.dig("height") || 0
      if width > 300 && height > 300
        score += 5
      end
      
      { item: item, score: score }
    end
    
    # Return the highest scored image, or first image as fallback
    best = scored_images.max_by { |img| img[:score] }
    return items.first if best.nil? || best[:score] <= 0
    best[:item]
  end

  def find_best_logo(items, query)
    # Score images for logos
    scored_images = items.map do |item|
      score = 0
      title = (item["title"] || "").downcase
      snippet = (item["snippet"] || "").downcase
      link = item["link"] || ""
      
      # Prefer images with "logo" in title/snippet
      if title.include?("logo") || snippet.include?("logo")
        score += 20
      end
      
      # Prefer official domains (company websites)
      official_domains = ["amazon.com", "bestbuy.com", "target.com", "walmart.com", 
                          "apple.com", "samsung.com", "sony.com", "dyson.com",
                          "nordstrom.com", "victoriassecret.com", "mac.com"]
      if official_domains.any? { |domain| link.include?(domain) }
        score += 25
      end
      
      # Prefer square/icon-like images for logos
      width = item["image"]&.dig("width") || 0
      height = item["image"]&.dig("height") || 0
      if width > 0 && height > 0
        aspect_ratio = width.to_f / height
        # Prefer square-ish images (logos are often square)
        if aspect_ratio >= 0.8 && aspect_ratio <= 1.2
          score += 10
        end
      end
      
      # Avoid product photos when looking for logos
      if title.include?("product") || snippet.include?("product")
        score -= 10
      end
      
      { item: item, score: score }
    end
    
    # Return the highest scored image, or first image as fallback
    best = scored_images.max_by { |img| img[:score] }
    return items.first if best.nil? || best[:score] <= 0
    best[:item]
  end

  def valid_image_url?(url)
    return false if url.blank?
    
    # Check if URL is valid
    uri = URI.parse(url)
    uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    false
  end
end

