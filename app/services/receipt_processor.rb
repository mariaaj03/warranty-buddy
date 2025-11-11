require "tempfile"

class ReceiptProcessor
  def initialize
    @temp_files = []
    @vision_service = GoogleVisionService.new
    @ai_service = AiService.new
  end

  def process_pdf(pdf_data)
    return nil unless pdf_data.present?

    begin
      text = @vision_service.extract_text_from_pdf(pdf_data)
      return nil if text.blank?

      parse_receipt_with_ai(text)
    rescue => e
      Rails.logger.error "PDF processing failed: #{e.message}"
      nil
    end
  end

  def process_image(image_data, filename = nil)
    return nil unless image_data.present?

    begin
      text = @vision_service.extract_text_from_image(image_data)
      if text.blank?
        Rails.logger.warn "No text extracted from image. Vision API may not be configured or image may not contain readable text."
        return nil
      end

      Rails.logger.info "Extracted #{text.length} characters from image"
      result = parse_receipt_with_ai(text)
      Rails.logger.info "Parsed receipt data: #{result.inspect}" if result
      result
    rescue => e
      Rails.logger.error "Image OCR processing failed: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      nil
    end
  end

  def cleanup
    @temp_files.each do |file|
      file.close
      file.unlink
    rescue
      # Ignore cleanup errors
    end
    @temp_files.clear
  end

  private

  def create_temp_file(data, extension)
    temp_file = Tempfile.new([ "receipt", extension ])
    temp_file.binmode
    temp_file.write(data)
    temp_file.rewind
    @temp_files << temp_file
    temp_file
  end

  def determine_image_extension(filename)
    return nil unless filename.present?

    ext = File.extname(filename).downcase
    return ext if %w[.jpg .jpeg .png .gif .bmp .tiff].include?(ext)

    # Try to determine from content type or default to jpg
    ".jpg"
  end

  def parse_receipt_with_ai(text)
    return nil if text.blank?

    ai_result = @ai_service.extract_receipt_info(text)
    
    if ai_result && ai_result["is_receipt"] == true
      product_name = ai_result["product_name"]
      {
        product_name: product_name,
        merchant: ai_result["merchant"],
        purchase_date: ai_result["purchase_date"] ? Date.parse(ai_result["purchase_date"]) : nil,
        line_items: [{ name: product_name, quantity: 1, price: nil }],
        total_amount: nil,
        order_number: nil,
        warranty_length_months: ai_result["warranty_length_months"],
        warranty_type: ai_result["warranty_type"],
        return_policy_days: ai_result["return_policy_days"],
        return_deadline: ai_result["return_deadline"] ? Date.parse(ai_result["return_deadline"]) : nil
      }
    else
      fallback_data = parse_receipt_text(text)
      if fallback_data && fallback_data[:line_items]&.any?
        fallback_data[:product_name] = fallback_data[:line_items].first[:name]
      end
      fallback_data
    end
  end

  def parse_receipt_text(text)
    return nil if text.blank?

    {
      merchant: extract_merchant_from_receipt(text),
      purchase_date: extract_date_from_receipt(text),
      line_items: extract_items_from_receipt(text),
      total_amount: extract_total_from_receipt(text),
      order_number: extract_order_number_from_receipt(text)
    }
  end

  def extract_merchant_from_receipt(text)
    # Look for store names in the text - using regex patterns
    common_merchants = [
      "Amazon",
      "Best\\s+Buy",
      "Walmart",
      "Target",
      "Costco",
      "Newegg",
      "B&H\\s+Photo",
      "Apple",
      "Microsoft",
      "Home\\s+Depot",
      "Lowes"
    ]

    common_merchants.each do |merchant_pattern|
      if text.match?(/#{merchant_pattern}/i)
        # Return the cleaned up name without regex escapes
        return merchant_pattern.gsub(/\\s\+/, " ")
      end
    end

    # Look for patterns like "Thank you for shopping at [Store]"
    if match = text.match(/thank you for shopping at\s+([^\n\r]{2,50})/i)
      return match[1].strip
    end

    # Look for patterns like "Store: [Name]"
    if match = text.match(/store[:\s]+([^\n\r]{2,50})/i)
      return match[1].strip
    end

    nil
  end

  def extract_date_from_receipt(text)
    # Look for date patterns
    date_patterns = [
      /\b(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})\b/,
      /\b(\d{4}[\/\-]\d{1,2}[\/\-]\d{1,2})\b/,
      /\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},?\s+\d{4}\b/i,
      /\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\.?\s+\d{1,2},?\s+\d{4}\b/i
    ]

    date_patterns.each do |pattern|
      if match = text.match(pattern)
        begin
          return Date.parse(match[1])
        rescue ArgumentError
          # Try next pattern
        end
      end
    end

    nil
  end

  def extract_items_from_receipt(text)
    items = []

    # Look for line item patterns
    line_patterns = [
      /(\d+)\s+(.{3,80}?)\s+([0-9\.,]+)/,
      /(.{3,80}?)\s+([0-9\.,]+)/
    ]

    line_patterns.each do |pattern|
      text.scan(pattern).each do |match|
        if match.length == 3
          # Pattern with quantity
          qty = match[0].to_i
          name = match[1].strip
          price = parse_price(match[2])
        else
          # Pattern without quantity
          qty = 1
          name = match[0].strip
          price = parse_price(match[1])
        end

        next if name.length < 3 || price.nil?

        items << {
          name: name,
          quantity: qty,
          price: price
        }
      end
    end

    items.uniq { |item| item[:name] }
  end

  def extract_total_from_receipt(text)
    total_patterns = [
      /total[:\s]*\$?([0-9\.,]+)/i,
      /grand total[:\s]*\$?([0-9\.,]+)/i,
      /amount due[:\s]*\$?([0-9\.,]+)/i,
      /subtotal[:\s]*\$?([0-9\.,]+)/i
    ]

    total_patterns.each do |pattern|
      if match = text.match(pattern)
        return parse_price(match[1])
      end
    end

    nil
  end

  def extract_order_number_from_receipt(text)
    order_patterns = [
      /order\s*(?:number|#|id)[:\s]*([A-Z0-9\-]{6,40})/i,
      /receipt\s*(?:number|#)[:\s]*([A-Z0-9\-]{6,40})/i,
      /transaction\s*(?:number|id)[:\s]*([A-Z0-9\-]{6,40})/i
    ]

    order_patterns.each do |pattern|
      if match = text.match(pattern)
        return match[1].strip
      end
    end

    nil
  end

  def parse_price(price_string)
    return nil if price_string.blank?

    # Remove currency symbols and clean up
    cleaned = price_string.gsub(/[^\d\.,]/, "")
    return nil if cleaned.blank?

    # Handle different decimal/thousands separator formats
    if cleaned.match(/^\d{1,3}(\,\d{3})+\.\d{2}$/)
      # Format: 1,234.56 (US format with thousands separator)
      cleaned = cleaned.gsub(",", "")
    elsif cleaned.match(/^\d{1,3}(\.\d{3})+\,\d{2}$/)
      # Format: 1.234,56 (European format)
      cleaned = cleaned.gsub(".", "").gsub(",", ".")
    elsif cleaned.count(",") == 1 && cleaned.count(".") == 0
      # Format: 123,45 (European decimal)
      cleaned = cleaned.gsub(",", ".")
    elsif cleaned.count(".") > 1
      # Multiple dots, assume thousands separator
      cleaned = cleaned.gsub(".", "")
    end

    cleaned.to_f
  rescue
    nil
  end
end
