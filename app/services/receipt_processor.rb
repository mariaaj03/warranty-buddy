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

      parse_receipt_text_first(text)
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
        Rails.logger.warn "Vision API key configured: #{@vision_service.instance_variable_get(:@api_key).present?}"
        return nil
      end

      Rails.logger.info "Extracted #{text.length} characters from image"
      Rails.logger.debug "First 500 chars of extracted text: #{text[0..500]}"
      
      result = parse_receipt_text_first(text)
      
      if result
        Rails.logger.info "✅ Parsed receipt data: merchant=#{result[:merchant]}, product=#{result[:product_name]}, items=#{result[:line_items]&.length || 0}"
      else
        Rails.logger.warn "⚠️ Receipt parsing returned nil - text was extracted but couldn't parse structure"
        Rails.logger.debug "Full extracted text: #{text[0..1000]}"
      end
      
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

  def parse_receipt_text_first(text)
    return nil if text.blank?

    result = parse_receipt_text(text)
    
    if result && result[:line_items]&.any?
      result[:product_name] = result[:line_items].first[:name]
      Rails.logger.info "✅ Regex parsing succeeded: #{result[:product_name]} from #{result[:merchant]}"
      return result
    end

    Rails.logger.info "🤖 Regex parsing found no line items, trying AI extraction..."
    begin
      ai_result = @ai_service.extract_receipt_info(text)
      
      if ai_result && ai_result["is_receipt"] == true
        product_name = ai_result["product_name"]
        Rails.logger.info "✅ AI extraction succeeded: #{product_name} from #{ai_result['merchant']}"
        {
          product_name: product_name,
          merchant: ai_result["merchant"] || result&.dig(:merchant),
          purchase_date: ai_result["purchase_date"] ? Date.parse(ai_result["purchase_date"]) : result&.dig(:purchase_date),
          line_items: [{ name: product_name, quantity: 1, price: nil }],
          total_amount: result&.dig(:total_amount),
          order_number: result&.dig(:order_number),
          warranty_length_months: ai_result["warranty_length_months"],
          warranty_type: ai_result["warranty_type"],
          return_policy_days: ai_result["return_policy_days"],
          return_deadline: ai_result["return_deadline"] ? Date.parse(ai_result["return_deadline"]) : nil
        }
      else
        Rails.logger.warn "⚠️ AI did not recognize this as a receipt"
        result
      end
    rescue => e
      Rails.logger.warn "⚠️ AI parsing failed: #{e.message}"
      Rails.logger.warn e.backtrace.first(3).join("\n")
      result
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
      "Lowes",
      "Victoria'?s\\s+Secret",
      "Sephora",
      "Nordstrom",
      "Macy'?s",
      "Ulta",
      "Zappos"
    ]

    common_merchants.each do |merchant_pattern|
      if text.match?(/#{merchant_pattern}/i)
        # Return the cleaned up name without regex escapes
        cleaned = merchant_pattern.gsub(/\\s\+/, " ").gsub(/'\\?s/, "'s")
        return cleaned
      end
    end

    # Look for patterns like "Thank you for shopping at [Store]"
    if match = text.match(/thank you for shopping at\s+([^\n\r]{2,50})/i)
      merchant = match[1].strip
      merchant = merchant.split(',').first.strip if merchant.include?(',')
      return merchant
    end

    # Look for patterns like "Store: [Name]"
    if match = text.match(/store[:\s]+([^\n\r]{2,50})/i)
      return match[1].strip
    end

    nil
  end

  def extract_date_from_receipt(text)
    lines = text.split(/\n|\r\n/).map(&:strip).first(40)
    
    excluded_patterns = [
      /return date/i, /serial number/i, /part number/i, /imei/i,
      /purchased\s+nov\s+\d{1,2},?\s+\d{4}/i,
      /purchased\s+\d{1,2}\s+months/i
    ]
    
    date_patterns = [
      /(?:date\/time|date|time)[:\s]*(\d{4}[\/\-]\d{1,2}[\/\-]\d{1,2})/,
      /(?:date\/time|date|time)[:\s]*((?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},?\s+\d{4})/i,
      /\b((?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},?\s+\d{4})\s+\d{1,2}:\d{2}\s*(?:AM|PM)?/i,
      /\b((?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},?\s+\d{4})\b/i,
      /\b((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\.?\s+\d{1,2},?\s+\d{4})\b/i,
      /\b(\d{4}[\/\-]\d{1,2}[\/\-]\d{1,2})\b/,
      /\b(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{4})\b/
    ]

    lines.each do |line|
      excluded_patterns.each do |pattern|
        next if line.match?(pattern)
      end
      
      next if line.match?(/purchased.*\d+\s+months/i)
      
      date_patterns.each do |pattern|
        if match = line.match(pattern)
          date_str = match[1] || match[0]
          
          if date_str.match?(/\d{1,2}:\d{2}/)
            date_str = date_str.split(/\s+\d{1,2}:\d{2}/).first
            date_str = date_str.split(/\s+(?:AM|PM)/i).first if date_str.match?(/\s+(?:AM|PM)/i)
          end
          
          if date_str.match?(/\d{4}\/\d{2}\/\d{2}/)
            date_match = date_str.match(/(\d{4}\/\d{1,2}\/\d{1,2})/)
            date_str = date_match[1] if date_match
          end
          
          date_str = date_str.strip
          
          begin
            parsed_date = Date.parse(date_str)
            if parsed_date <= Date.today && parsed_date >= Date.today - 3650
              Rails.logger.info "Extracted date: #{parsed_date} from line: #{line} (parsed from: #{date_str})"
              return parsed_date
            end
          rescue ArgumentError => e
            Rails.logger.warn "Failed to parse date: #{date_str} - #{e.message}"
          end
        end
      end
    end

    date_patterns.each do |pattern|
      if match = text.match(pattern)
        date_str = match[1] || match[0]
        
        if date_str.match?(/\d{1,2}:\d{2}/)
          date_str = date_str.split(/\s+\d{1,2}:\d{2}/).first
          date_str = date_str.split(/\s+(?:AM|PM)/i).first if date_str.match?(/\s+(?:AM|PM)/i)
        end
        
        if date_str.match?(/\d{4}\/\d{2}\/\d{2}/)
          date_match = date_str.match(/(\d{4}\/\d{1,2}\/\d{1,2})/)
          date_str = date_match[1] if date_match
        end
        
        date_str = date_str.strip
        
        begin
          parsed_date = Date.parse(date_str)
          if parsed_date <= Date.today && parsed_date >= Date.today - 3650
            Rails.logger.info "Extracted date: #{parsed_date} from text (parsed from: #{date_str})"
            return parsed_date
          end
        rescue ArgumentError => e
          Rails.logger.warn "Failed to parse date: #{date_str} - #{e.message}"
        end
      end
    end

    nil
  end

  def extract_items_from_receipt(text)
    items = []
    lines = text.split(/\n|\r\n/).map(&:strip).reject(&:blank?)
    
    excluded_phrases = [
      /payment method/i, /purchased/i, /subtotal/i, /total/i, /tax/i, /shipping/i,
      /discount/i, /order/i, /receipt/i, /merchant/i, /store/i, /thank you/i,
      /part number/i, /serial number/i, /imei/i, /return date/i, /for support/i,
      /www\./i, /http/i, /email/i, /phone/i, /address/i, /warranty/i, /months/i
    ]

    lines.each_with_index do |line, index|
      next if line.length < 5
      
      excluded_phrases.each do |pattern|
        next if line.match?(pattern)
      end
      
      email_pattern = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/
      next if line.match?(email_pattern)
      next if line.match?(/^\d+$/)
      next if line.match?(/^\$/)
      next if line.match?(/^\d{4}-\d{2}-\d{2}/)
      next if line.match?(/\d{2}:\d{2}/)
      
      if line.match?(/^[A-Z][a-zA-Z0-9\s\-]{8,100}$/)
        next_line = lines[index + 1] if index + 1 < lines.length
        next_next = lines[index + 2] if index + 2 < lines.length
        
        if next_line && next_line.match?(/^Part Number:/i)
          price_line = nil
          
          (index + 2..[index + 6, lines.length - 1].min).each do |i|
            candidate = lines[i]
            if candidate && candidate.match?(/^\$\s*([0-9]{1,3}(?:[,\s][0-9]{3})*(?:\.[0-9]{2})?)/)
              price_line = candidate
              break
            end
          end
          
          if price_line
            price_match = price_line.match(/\$\s*([0-9]{1,3}(?:[,\s][0-9]{3})*(?:\.[0-9]{2})?)/)
            if price_match
              price = parse_price(price_match[1])
              if price && price > 0 && price < 100000
                items << {
                  name: line,
                  quantity: 1,
                  price: price
                }
              end
            end
          end
        end
      end
    end

    if items.empty?
      lines.each_with_index do |line, index|
        next if line.length < 3
        next if line.match?(/^(payment method|purchased|subtotal|total|tax|shipping|discount|order|receipt|date|merchant|store|thank you|part number|serial|imei|return|for support|www\.|http)/i)
        
        email_pattern = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/
        next if line.match?(email_pattern)
        
        price_match = line.match(/\$\s*([0-9]{1,3}(?:[,\s][0-9]{3})*(?:\.[0-9]{2})?)/)
        if price_match
          price = parse_price(price_match[1])
          next unless price && price > 0 && price < 100000
          
          (1..8).each do |offset|
            prev_index = index - offset
            next if prev_index < 0
            
            prev_line = lines[prev_index]
            next if prev_line.blank?
            
            excluded_phrases.each do |pattern|
              next if prev_line.match?(pattern)
            end
            
            next if prev_line.match?(email_pattern)
            next if prev_line.match?(/^\d+$/)
            next if prev_line.match?(/^\$/)
            next if prev_line.match?(/^\d{4}-\d{2}-\d{2}/)
            next if prev_line.match?(/\d{2}:\d{2}/)
            next if prev_line.match?(/^(part number|serial|imei|return|for support)/i)
            
            if prev_line.match?(/^[A-Z][a-zA-Z0-9\s\-]{8,100}$/) && !prev_line.match?(/^\d+$/)
              items << {
                name: prev_line,
                quantity: 1,
                price: price
              }
              break
            end
          end
        end
      end
    end

    items.uniq { |item| item[:name] }.first(5)
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
