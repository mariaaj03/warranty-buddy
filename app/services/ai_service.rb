class AiService
  def initialize
    begin
      require "gemini-ai"
      @client = Gemini.new(
        credentials: {
          service: "generative-language-api",
          api_key: Rails.application.credentials.dig(:google, :gemini_api_key)
        },
        options: { model: "gemini-2.0-flash", server_sent_events: false }
      )
    rescue LoadError => e
      Rails.logger.error "Gemini AI gem not available: #{e.message}"
      @client = nil
    rescue => e
      Rails.logger.error "Gemini AI client initialization failed: #{e.message}"
      @client = nil
    end
  end

  def extract_receipt_info(email_content)
    return nil unless @client

    Rails.logger.info "🤖 AI Service: Starting receipt analysis"
    Rails.logger.debug "📧 Email content length: #{email_content.length}"

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

    Rails.logger.debug "📝 Prompt length: #{prompt.length}"

    response = @client.generate_content({
      contents: { role: "user", parts: { text: prompt } }
    })

    response_text = response.dig("candidates", 0, "content", "parts", 0, "text")
    Rails.logger.debug "🤖 AI Response: #{response_text}"

    # Clean up markdown code blocks if present
    response_text = response_text.gsub(/```json\s*/, "").gsub(/```\s*$/, "").strip

    result = JSON.parse(response_text)
    Rails.logger.info "🤖 AI Analysis Result: #{result.inspect}"

    # Only return data if AI confirms this is a receipt
    if result["is_receipt"] == true
      Rails.logger.info "✅ AI confirmed this is a receipt"
      result
    else
      Rails.logger.info "❌ AI determined this is not a receipt"
      nil
    end
  rescue => e
    Rails.logger.error "💥 AI extraction failed: #{e.message}"
    Rails.logger.error "💥 Backtrace: #{e.backtrace.first(5).join('\n')}"
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

    response = @client.generate_content({
      contents: { role: "user", parts: { text: prompt } }
    })

    response_text = response.dig("candidates", 0, "content", "parts", 0, "text")

    # Clean up markdown code blocks if present
    response_text = response_text.gsub(/```json\s*/, "").gsub(/```\s*$/, "").strip

    JSON.parse(response_text)
  rescue => e
    Rails.logger.error "AI warranty lookup failed: #{e.message}"
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

    response = @client.generate_content({
      contents: { role: "user", parts: { text: prompt } }
    })

    response_text = response.dig("candidates", 0, "content", "parts", 0, "text")

    # Clean up markdown code blocks if present
    response_text = response_text.gsub(/```json\s*/, "").gsub(/```\s*$/, "").strip

    JSON.parse(response_text)
  rescue => e
    Rails.logger.error "AI warranty eligibility check failed: #{e.message}"
    nil
  end
end
