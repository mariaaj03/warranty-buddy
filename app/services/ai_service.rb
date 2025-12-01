require "net/http"
require "json"
require "uri"
require "cgi"

class GeminiRateLimitError < StandardError
end

class AiService
  def initialize(client = nil)
    if client
      @client = client
      @api_key = nil
    else
      @api_key = ENV["GOOGLE_GEMINI_API_KEY"] || Rails.application.credentials.dig(:google, :gemini_api_key)
      @client = @api_key.present? ? :rest_api : nil
      
      unless @api_key.present?
        Rails.logger.error "Gemini API key not found in credentials or environment"
      end
    end
  end

  def extract_receipt_info(email_content)
    return nil unless @client

    prompt = <<~PROMPT
      Analyze this email and determine if it contains purchase/receipt information for a physical product.

      Look for ANY indication this is a purchase receipt for a physical item:
      - Product names, descriptions, or SKUs
      - Purchase amounts, prices, or totals
      - Order numbers or confirmation numbers
      - Shipping information, tracking numbers
      - Merchant/store information
      - Words like: "order", "purchase", "bought", "shipped", "delivered", "receipt", "invoice", "confirmation"

      If this is NOT a receipt for a physical product (e.g., subscription, service, digital download, newsletter, course announcement, etc.), return: {"is_receipt": false}

      If this IS a receipt for a physical product, extract the following information and return a JSON object:
      {
        "is_receipt": true,
        "product_name": "exact product name or description (required)",
        "merchant": "store/website/company name (required)",
        "purchase_date": "YYYY-MM-DD format (required - use email date if not specified)",
        "warranty_length_months": number (only if explicitly mentioned, otherwise null),
        "warranty_type": "manufacturer/merchant/extended" (only if mentioned, otherwise null),
        "return_policy_days": number (return deadline in days, if mentioned),
        "return_deadline": "YYYY-MM-DD format" (specific return deadline date, if mentioned),
      }

      IMPORTANT: Accept ANY physical product purchase receipt, even if warranty/return info is missing.#{' '}
      Default to 12 months warranty if not specified. Use the email date as purchase date if not specified.

      Email content:
      #{email_content[0..2000]}...
    PROMPT

    response_text = call_gemini_api(prompt)
    
    # Clean up markdown code blocks if present
    response_text = response_text.gsub(/```json\s*/, "").gsub(/```\s*$/, "").strip

    result = JSON.parse(response_text)

    # Only return data if AI confirms this is a receipt
    if result["is_receipt"] == true
      result
    else
      nil
    end
  rescue => e
    nil
  end

  def lookup_warranty_info(product_name, merchant = nil)
    return nil unless @client

    prompt = <<~PROMPT
      Look up warranty information for this product. Return a JSON object with:
      {
        "standard_warranty_months": number,
        "warranty_terms": "brief description of what's covered",
        "exclusions": "what's not covered",
        "return_policy_days": number,
      }

      Product: #{product_name}
      Merchant: #{merchant || "unknown"}

      Be conservative and only include information you're confident about.
    PROMPT

    response_text = call_gemini_api(prompt)
    response_text = response_text.gsub(/```json\s*/, "").gsub(/```\s*$/, "").strip

    JSON.parse(response_text)
  rescue => e
    nil
  end

  def check_warranty_eligibility(product_name, issue_description, warranty_terms)
    return nil unless @client

    prompt = <<~PROMPT
      Determine if this product issue is covered under warranty. Return a JSON object with:
      {
        "is_covered": true/false,
        "reasoning": "explanation of decision",
        "recommended_action": "what the user should do",
      }

      Product: #{product_name}
      Issue: #{issue_description}
      Warranty Terms: #{warranty_terms}
    PROMPT

    response_text = call_gemini_api(prompt)
    response_text = response_text.gsub(/```json\s*/, "").gsub(/```\s*$/, "").strip

    JSON.parse(response_text)
  rescue => e
    nil
  end

  def extract_receipt_info_from_image(image_base64)
    return nil unless @client

    prompt = <<~PROMPT
      Analyze this receipt image and extract purchase/receipt information for a physical product.

      Look for:
      - Product names, descriptions, or SKUs
      - Purchase amounts, prices, or totals
      - Order numbers or confirmation numbers
      - Merchant/store information
      - Purchase date
      - Warranty information (if mentioned)
      - Return policy information (if mentioned)

      If this is NOT a receipt for a physical product (e.g., subscription, service, digital download, etc.), return: {"is_receipt": false}

      If this IS a receipt for a physical product, extract the following information and return a JSON object:
      {
        "is_receipt": true,
        "product_name": "exact product name or description (required - extract the main product/item purchased)",
        "merchant": "store/website/company name (required)",
        "purchase_date": "YYYY-MM-DD format (required - extract from receipt)",
        "warranty_length_months": number (only if explicitly mentioned, otherwise null),
        "warranty_type": "manufacturer/merchant/extended" (only if mentioned, otherwise null),
        "return_policy_days": number (return deadline in days, if mentioned),
        "return_deadline": "YYYY-MM-DD format" (specific return deadline date, if mentioned),
      }

      IMPORTANT: 
      - Extract the actual product name from the receipt (e.g., "SMLSS HIPSTER", "iPhone 15 Pro", etc.), NOT generic terms like "Order", "Receipt", "Customer Service", "Contact Us", "Help", "Support", "Returns", "Payment Method", etc.
      - For purchase dates in M/D/YY or M/D/YYYY format (e.g., "10/20/25" or "10/20/2025"), interpret as month/day/year (US format).
      - Default to 12 months warranty if not specified. Extract the purchase date from the receipt.
      - Return dates in YYYY-MM-DD format (e.g., "2025-10-20" for October 20, 2025).
    PROMPT

    response_text = call_gemini_api_with_image(prompt, image_base64)
    
    response_text = response_text.gsub(/```json\s*/, "").gsub(/```\s*$/, "").strip

    result = JSON.parse(response_text)

    if result["is_receipt"] == true
      result
    else
      nil
    end
  rescue => e
    nil
  end

  def answer_warranty_question(question, search_results = nil)
    return nil unless @client

    search_context = ""
    if search_results && search_results.any?
      search_context = "\n\nRelevant information from web search:\n"
      search_results.first(5).each_with_index do |result, idx|
        search_context += "#{idx + 1}. #{result[:title]}\n   #{result[:snippet]}\n   Source: #{result[:url]}\n\n"
      end
    end

    prompt = <<~PROMPT
      You are a helpful warranty assistant. Answer the user's question about warranty coverage, product issues, or warranty policies.

      Be specific, helpful, and cite sources when available. If you're not certain, say so.

      User Question: #{question}
      #{search_context}

      Provide a clear, concise answer. If the question is about a specific product issue (like water damage, breakage, etc.), explain:
      1. Whether it's typically covered under warranty
      2. Why or why not
      3. What the user should do next
      4. Any relevant warranty terms or exclusions

      Format your response as plain text (no markdown). Be conversational but informative.
    PROMPT

    response_text = call_gemini_api(prompt)
    stripped = response_text&.strip
    stripped.present? ? stripped : "I'm sorry, I couldn't generate a response. Please try rephrasing your question."
  rescue => e
    raise e
  end

  private

  def call_gemini_api(prompt)
    api_key = @api_key || ENV["GOOGLE_GEMINI_API_KEY"] || Rails.application.credentials.dig(:google, :gemini_api_key)
    return nil unless api_key.present?

    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=#{CGI.escape(api_key)}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    # In development, allow self-signed certificates and skip CRL checks
    if Rails.env.development?
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    
    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request.body = {
      contents: [{
        parts: [{
          text: prompt
        }]
      }]
    }.to_json

    response = http.request(request)
    
    if response.code == "200"
      result = JSON.parse(response.body)
      result.dig("candidates", 0, "content", "parts", 0, "text") || ""
    elsif response.code == "429"
      error_data = JSON.parse(response.body) rescue {}
      error_message = error_data.dig("error", "message") || "Rate limit exceeded"
      raise GeminiRateLimitError.new(error_message)
    else
      error_data = JSON.parse(response.body) rescue {}
      error_message = error_data.dig("error", "message") || "API error"
      raise "Gemini API error: #{response.code} - #{error_message}"
    end
  rescue JSON::ParserError => e
    raise "Gemini API error: Invalid response format"
  rescue GeminiRateLimitError
    raise
  rescue => e
    raise e
  end

  def call_gemini_api_with_image(prompt, image_base64)
    api_key = @api_key || ENV["GOOGLE_GEMINI_API_KEY"] || Rails.application.credentials.dig(:google, :gemini_api_key)
    return nil unless api_key.present?

    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=#{CGI.escape(api_key)}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    # In development, allow self-signed certificates and skip CRL checks
    if Rails.env.development?
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    
    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request.body = {
      contents: [{
        parts: [
          { text: prompt },
          {
            inline_data: {
              mime_type: "image/png",
              data: image_base64
            }
          }
        ]
      }]
    }.to_json

    response = http.request(request)
    
    if response.code == "200"
      result = JSON.parse(response.body)
      result.dig("candidates", 0, "content", "parts", 0, "text") || ""
    elsif response.code == "429"
      error_data = JSON.parse(response.body) rescue {}
      error_message = error_data.dig("error", "message") || "Rate limit exceeded"
      raise GeminiRateLimitError.new(error_message)
    else
      error_data = JSON.parse(response.body) rescue {}
      error_message = error_data.dig("error", "message") || "API error"
      raise "Gemini API error: #{response.code} - #{error_message}"
    end
  rescue JSON::ParserError => e
    raise "Gemini API error: Invalid response format"
  rescue GeminiRateLimitError
    raise
  rescue => e
    raise e
  end

end
