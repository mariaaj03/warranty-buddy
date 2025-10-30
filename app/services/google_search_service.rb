require "net/http"
require "json"
require "uri"

class GoogleSearchService
  def initialize
    @api_key = Rails.application.credentials.dig(:google, :search_api_key)
    @search_engine_id = Rails.application.credentials.dig(:google, :search_engine_id)
  end

  def lookup_warranty_info(product_name, merchant = nil)
    return nil unless @api_key && @search_engine_id

    search_query = build_warranty_query(product_name, merchant)
    search_results = perform_search(search_query)

    return nil unless search_results&.any?

    extract_warranty_info(search_results, product_name, merchant)
  end

  private

  def build_warranty_query(product_name, merchant)
    base_query = "#{product_name} warranty length months"
    base_query += " #{merchant}" if merchant.present?
    base_query += " manufacturer warranty return policy"
    base_query
  end

  def perform_search(query)
    uri = URI("https://www.googleapis.com/customsearch/v1")
    params = {
      key: @api_key,
      cx: @search_engine_id,
      q: query,
      num: 5
    }
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)

    if response.code == "200"
      JSON.parse(response.body)["items"] || []
    else
      Rails.logger.error "Google Search API error: #{response.code} - #{response.body}"
      []
    end
  rescue => e
    Rails.logger.error "Google Search API request failed: #{e.message}"
    []
  end

  def extract_warranty_info(search_results, product_name, merchant)
    warranty_info = {
      warranty_months: nil,
      return_policy_days: nil,
      source: "google_search",
      details: []
    }

    search_results.each do |result|
      title = result["title"] || ""
      snippet = result["snippet"] || ""
      content = "#{title} #{snippet}".downcase

      # Look for warranty length patterns
      warranty_patterns = [
        /(\d+)\s*(?:month|months?)\s*(?:warranty|guarantee)/i,
        /warranty[:\s]*(\d+)\s*(?:month|months?)/i,
        /(\d+)\s*(?:year|years?)\s*(?:warranty|guarantee)/i,
        /warranty[:\s]*(\d+)\s*(?:year|years?)/i
      ]

      warranty_patterns.each do |pattern|
        if match = content.match(pattern)
          months = match[1].to_i
          # Convert years to months
          months *= 12 if content.match?(/year/i)

          if warranty_info[:warranty_months].nil? || months > warranty_info[:warranty_months]
            warranty_info[:warranty_months] = months
          end
        end
      end

      # Look for return policy patterns
      return_patterns = [
        /(\d+)\s*(?:day|days?)\s*(?:return|return policy)/i,
        /return[:\s]*(\d+)\s*(?:day|days?)/i,
        /(\d+)\s*(?:day|days?)\s*(?:money back|refund)/i
      ]

      return_patterns.each do |pattern|
        if match = content.match(pattern)
          days = match[1].to_i
          if warranty_info[:return_policy_days].nil? || days > warranty_info[:return_policy_days]
            warranty_info[:return_policy_days] = days
          end
        end
      end

      # Store relevant details
      if content.match?(/warranty|guarantee|return/i)
        warranty_info[:details] << {
          title: title,
          snippet: snippet,
          url: result["link"]
        }
      end
    end

    # If no specific warranty found, try to infer from product type
    if warranty_info[:warranty_months].nil?
      inferred_warranty = infer_warranty_from_product_type(product_name)
      if inferred_warranty
        warranty_info[:warranty_months] = inferred_warranty
      end
    end

    # If no return policy found, use default
    if warranty_info[:return_policy_days].nil?
      warranty_info[:return_policy_days] = 30
    end

    warranty_info
  end

  def infer_warranty_from_product_type(product_name)
    product_lower = product_name.downcase

    # Electronics typically have 12 months
    if product_lower.match?(/phone|computer|laptop|tablet|headphones|speaker|camera|tv|monitor|electronic/i)
      return 12
    end

    # Appliances typically have 12-24 months
    if product_lower.match?(/refrigerator|washer|dryer|dishwasher|stove|oven|appliance/i)
      return 24
    end

    # Tools typically have 12-36 months
    if product_lower.match?(/tool|drill|saw|hammer|wrench/i)
      return 24
    end

    # Clothing typically has 30-90 days
    if product_lower.match?(/shirt|pants|dress|shoes|clothing|apparel/i)
      return 1 # 1 month for clothing
    end

    # Default to 12 months
    12
  end
end
