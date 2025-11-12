require "google/apis/gmail_v1"

class GmailService
  def initialize(access_token, refresh_token = nil, user = nil)
    @fetcher = GmailFetcher.new(access_token, refresh_token, user)
    @receipt_processor = ReceiptProcessor.new
  end

  def parse_receipt_emails(user_id = "me")
    return [] unless @fetcher.service.authorization

    begin
      Rails.logger.info "🔍 Starting Gmail receipt parsing for user: #{user_id}"

      messages = @fetcher.list_order_messages(user_id, 50)
      Rails.logger.info "📊 Found #{messages.length} order messages"

      parsed_receipts = []
      processed_count = 0
      receipts_found = 0

      messages.each_with_index do |message, index|
        begin
          Rails.logger.info "📧 Processing message #{index + 1}/#{messages.length} (ID: #{message.id})"
          full_message = @fetcher.get_message(message.id, user_id)

          subject = extract_header(full_message, "Subject") || ""
          from = extract_header(full_message, "From") || ""
          date_header = extract_header(full_message, "Date")

          Rails.logger.info "📧 Subject: '#{subject}' from #{from}"

          html_content = @fetcher.extract_html_from_message(full_message)
          text_content = @fetcher.extract_text_from_message(full_message)
          parsed_receipt = parse_email_content(html_content, text_content, subject, from, date_header, full_message.id)
          processed_count += 1

          if parsed_receipt
            receipts_found += 1
            Rails.logger.info "✅ Parsed receipt: #{parsed_receipt[:product_name]} from #{parsed_receipt[:merchant]}"
            parsed_receipts << parsed_receipt
          else
            Rails.logger.info "❌ Not a valid receipt"
          end

          attachments = @fetcher.extract_attachments(full_message)
          if attachments.any?
            Rails.logger.info "📎 Found #{attachments.length} attachments, processing..."
            attachment_receipts = process_attachments(attachments, full_message.id, user_id)
            parsed_receipts.concat(attachment_receipts)
            receipts_found += attachment_receipts.length
          end

        rescue => e
          Rails.logger.error "💥 Failed to parse message #{message.id}: #{e.message}"
        end
      end

      Rails.logger.info "🎯 Final Results: #{processed_count} messages processed, #{receipts_found} receipts found"
      parsed_receipts
    rescue => e
      Rails.logger.error "💥 Gmail API error: #{e.message}"
      []
    ensure
      @receipt_processor.cleanup
    end
  end

  private

  def extract_header(message, header_name)
    message.payload.headers.find { |h| h.name == header_name }&.value
  end

  def parse_email_content(html_content, text_content, subject, from, date_header, message_id)
    promotional_keywords = [
      /select items to arrive/i, /last minute gifts/i, /gifts delivered today/i,
      /newsletter/i, /marketing/i, /advertisement/i, /unsubscribe/i
    ]
    
    return nil if promotional_keywords.any? { |pattern| subject.match?(pattern) }
    return nil if subject.match?(/^(select items|shop now|buy now|save now|deal of|special offer)/i)
    
    merchant = extract_merchant_from_headers(from, html_content, text_content)
    return nil if merchant == "Digital"
    
    parser_class = MerchantParsers.get_parser(merchant)

    parsed_data = parser_class.parse(html_content, text_content)

    generic_parser = nil
    if parsed_data.nil?
      generic_parser = EmailOrderParser.new(html_content, text_content, subject, from)
      parsed_data = generic_parser.parse
    end

    return nil unless parsed_data
    
    line_items = parsed_data[:line_items] || []
    order_number = parsed_data[:order_number]
    
    if order_number.blank?
      generic_parser ||= EmailOrderParser.new(html_content, text_content, subject, from)
      order_number = generic_parser.extract_order_number_from_subject
    end
    
    return nil if line_items.empty? && order_number.blank?
    
    primary_item = line_items.first
    product_name = primary_item&.dig(:name)
    
    if product_name.blank? && order_number.present?
      Rails.logger.info "🔍 No product name found in line items for order #{order_number}, trying extraction methods..."
      
      if product_name.blank? && subject.present?
        product_name = extract_product_name_from_subject_line(subject, order_number)
        Rails.logger.info "📝 Subject extraction result: #{product_name.inspect}" if product_name.present?
      end
      
      if product_name.blank?
        product_name = extract_product_name_from_email_content(html_content, text_content, subject)
        Rails.logger.info "📧 Email content extraction result: #{product_name.inspect}" if product_name.present?
      end
      
      if product_name.blank?
        email_text = [text_content, html_content].compact.join("\n")
        if email_text.present? && email_text.length > 50
          Rails.logger.info "🤖 Trying AI extraction (Gemini API) for order #{order_number}..."
          begin
            ai_service = AiService.new
            if ai_service.instance_variable_get(:@client)
              ai_result = ai_service.extract_receipt_info(email_text[0..3000])
              if ai_result && ai_result["product_name"].present?
                product_name = ai_result["product_name"]
                Rails.logger.info "✅ AI (Gemini) extracted product name: #{product_name}"
              else
                Rails.logger.warn "⚠️ AI returned no product name"
              end
            else
              Rails.logger.warn "⚠️ AI service not configured (missing Gemini API key)"
            end
          rescue => e
            Rails.logger.warn "⚠️ AI extraction failed: #{e.message}"
            Rails.logger.warn e.backtrace.first(3).join("\n")
          end
        end
      end
      
      if product_name.blank?
        product_name = "Order #{order_number}"
        Rails.logger.info "❌ Using fallback product name: #{product_name}"
      end
    end
    
    return nil if product_name.blank?

    {
      product_name: product_name,
      merchant: parsed_data[:merchant] || merchant || "Unknown",
      purchase_date: parsed_data[:purchase_date] || parse_email_date(date_header) || Date.today,
      warranty_months: determine_warranty_length(parsed_data[:merchant] || merchant, product_name),
      warranty_type: "manufacturer",
      return_policy_days: determine_return_policy(parsed_data[:merchant] || merchant),
      return_deadline: nil,
      source: "gmail_parsed",
      raw_email_id: message_id,
      order_number: order_number || parsed_data[:order_number],
      total_amount: parsed_data[:total_amount]
    }
  end

  def extract_merchant_from_headers(from, html_content, text_content)
    return nil if from.blank?

    # Extract from email domain
    email_match = from.match(/[\w.+-]+@([\w.-]+)/)
    if email_match
      domain = email_match[1].downcase
      domain_mapping = {
        "amazon.com" => "Amazon",
        "bestbuy.com" => "Best Buy",
        "walmart.com" => "Walmart",
        "target.com" => "Target",
        "costco.com" => "Costco",
        "newegg.com" => "Newegg",
        "bhphotovideo.com" => "B&H Photo",
        "sephora.com" => "Sephora",
        "nordstrom.com" => "Nordstrom",
        "victoriassecret.com" => "Victoria's Secret",
        "macys.com" => "Macy's",
        "ulta.com" => "Ulta",
        "zappos.com" => "Zappos",
        "apple.com" => "Apple"
      }
      return domain_mapping[domain]
    end

    # Extract from sender name
    name_match = from.match(/\A\s*"?([^"<]+?)"?\s*<[^>]+>\s*\z/)
    if name_match
      return clean_merchant_name(name_match[1])
    end

    clean_merchant_name(from)
  end

  def clean_merchant_name(name)
    return nil if name.blank?

    cleaned = name.strip
    cleaned = cleaned.gsub(/\b(?:noreply|no-reply|support|orders?)\b/i, "")
    cleaned = cleaned.gsub(/[\(\)\[\]<>@\-\.]+/, " ")  # Remove special characters
    cleaned = cleaned.gsub(/\s+/, " ")
    cleaned.strip
  end

  def extract_product_name_from_email_content(html_content, text_content, subject)
    return nil if text_content.blank? && html_content.blank?

    text = text_content || extract_text_from_html(html_content)
    return nil if text.blank?

    excluded_patterns = [
      /order\s+(?:number|#|id)/i, /receipt/i, /invoice/i, /confirmation/i,
      /shipping/i, /delivery/i, /tracking/i, /total/i, /subtotal/i,
      /tax/i, /discount/i, /payment/i, /thank you/i, /merchant/i,
      /store/i, /address/i, /phone/i, /email/i, /www\./i, /http/i
    ]

    lines = text.split(/\n|\r\n/).map(&:strip).reject(&:blank?)
    
    product_patterns = [
      /^([A-Z][a-zA-Z0-9\s\-&,\.]{10,80})$/,
      /^([A-Z][a-zA-Z0-9\s\-&,\.]{10,80})\s*[-–]\s*\$?[0-9]/,
      /^([A-Z][a-zA-Z0-9\s\-&,\.]{10,80})\s*Qty/i,
      /Item[:\s]+([A-Z][a-zA-Z0-9\s\-&,\.]{10,80})/i,
      /Product[:\s]+([A-Z][a-zA-Z0-9\s\-&,\.]{10,80})/i,
      /Description[:\s]+([A-Z][a-zA-Z0-9\s\-&,\.]{10,80})/i
    ]

    lines.each_with_index do |line, index|
      next if line.length < 10 || line.length > 100
      next if excluded_patterns.any? { |pattern| line.match?(pattern) }
      next if line.match?(/^\d+$/) || line.match?(/^\$/) || line.match?(/^[A-Z]{2,10}$/)
      
      product_patterns.each do |pattern|
        if match = line.match(pattern)
          candidate = match[1]&.strip
          next if candidate.blank?
          next if excluded_patterns.any? { |pat| candidate.match?(pat) }
          next if candidate.match?(/order|receipt|invoice|total|subtotal|tax|shipping|delivery/i)
          
          if candidate.length >= 10 && candidate.length <= 80
            Rails.logger.info "✅ Extracted product name from email: #{candidate}"
            return candidate
          end
        end
      end
    end

    nil
  end

  def extract_text_from_html(html)
    return "" if html.blank?
    require "nokogiri"
    doc = Nokogiri::HTML(html)
    doc.text
  end

  def extract_product_name_from_subject_line(subject, order_number = nil)
    return nil if subject.blank?

    promotional_keywords = [
      /select items/i, /arrive in time/i, /last minute/i, /gifts delivered/i,
      /valentine/i, /christmas/i, /holiday/i, /sale/i, /discount/i, /promo/i,
      /newsletter/i, /marketing/i, /refer a friend/i, /save.*off/i
    ]
    
    return nil if promotional_keywords.any? { |pattern| subject.match?(pattern) }
    return nil if subject.match?(/^(select|shop|buy|save|deal|offer|special|why not|tonight|last day)/i)

    patterns = [
      /(?:sold|bought|purchased|ordered|booked)\s+\d+\s+(?:tickets?|items?)\s+for\s+(.+?)(?:\s+[-–]\s+Order|$)/i,
      /(?:tickets?|items?)\s+for\s+(.+?)(?:\s+[-–]\s+Order|$)/i,
      /(.+?)\s+tickets?(?:\s+[-–]\s+Order|$)/i,
      /(.+?)\s+[-–]\s+Order\s*#/i,
      /(.+?)\s+Confirmation/i,
      /(.+?)\s+Parking\s+(?:Pass|Confirmation)/i,
      /receipt for\s+(.+?)(?:\s+[-–]|$)/i,
      /order\s+for\s+(.+?)(?:\s+[-–]|$)/i,
      /your order of\s+(.+?)(?:\s+[-–]|$)/i,
      /purchase\s+of\s+(.+?)(?:\s+[-–]|$)/i,
      /(.+?)\s+from\s+(.+?)(?:\s+[-–]\s+Order|$)/i
    ]

    patterns.each do |pattern|
      if match = subject.match(pattern)
        candidate = match[1]&.strip
        next if candidate.blank?
        next if candidate.length < 5 || candidate.length > 100
        next if promotional_keywords.any? { |pat| candidate.match?(pat) }
        next if candidate.match?(/^(order|receipt|confirmation|parking|ticket)$/i)
        
        candidate = candidate.gsub(/\s*[-–]\s*Order\s*#.*$/i, "").strip
        candidate = candidate.gsub(/\s*for\s+your\s+.*$/i, "").strip
        
        if candidate.length >= 5 && candidate.length <= 80
          Rails.logger.info "✅ Extracted from subject: #{candidate}"
          return candidate
        end
      end
    end

    nil
  end

  def extract_product_name_from_subject(subject)
    return "Unknown Product" if subject.blank?

    promotional_keywords = [
      /select items/i, /arrive in time/i, /last minute/i, /gifts delivered/i,
      /valentine/i, /christmas/i, /holiday/i, /sale/i, /discount/i, /promo/i
    ]
    
    return "Unknown Product" if promotional_keywords.any? { |pattern| subject.match?(pattern) }
    return "Unknown Product" if subject.match?(/^(select|shop|buy|save|deal|offer|special)/i)

    patterns = [
      /receipt for\s+(.+)/i,
      /order\s+for\s+(.+)/i,
      /your order of\s+(.+)/i,
      /purchase\s+of\s+(.+)/i
    ]

    patterns.each do |pattern|
      if match = subject.match(pattern)
        product = match[1].strip[0..120]
        return product unless promotional_keywords.any? { |pat| product.match?(pat) }
      end
    end

    "Unknown Product"
  end

  def parse_email_date(date_string)
    return nil if date_string.blank?

    begin
      Time.parse(date_string).to_date
    rescue ArgumentError
      nil
    end
  end

  def determine_warranty_length(merchant, product_name)
    return 12 if merchant.blank? || product_name.blank?

    # Try Google Search for more accurate warranty info
    begin
      search_service = GoogleSearchService.new
      warranty_info = search_service.lookup_warranty_info(product_name, merchant)

      if warranty_info && warranty_info[:warranty_months]
        Rails.logger.info "🔍 Found warranty info via Google Search: #{warranty_info[:warranty_months]} months"
        return warranty_info[:warranty_months]
      end
    rescue => e
      Rails.logger.warn "Google Search failed: #{e.message}"
    end

    # Fallback to merchant-specific defaults
    merchant_warranties = {
      "Amazon" => 12,
      "Best Buy" => 12,
      "Walmart" => 12,
      "Target" => 12,
      "Costco" => 12,
      "Apple" => 12,
      "Microsoft" => 12
    }

    # Check for electronics (typically 12 months)
    if product_name.match?(/phone|computer|laptop|tablet|headphones|speaker|camera|tv|monitor/i)
      return 12
    end

    # Check for appliances (typically 12-24 months)
    if product_name.match?(/refrigerator|washer|dryer|dishwasher|stove|oven/i)
      return 24
    end

    merchant_warranties[merchant] || 12
  end

  def determine_return_policy(merchant)
    return 30 if merchant.blank?

    merchant_policies = {
      "Amazon" => 30,
      "Best Buy" => 15,
      "Walmart" => 90,
      "Target" => 90,
      "Costco" => 90,
      "Apple" => 14,
      "Microsoft" => 30
    }

    merchant_policies[merchant] || 30
  end

  def process_attachments(attachments, message_id, user_id)
    receipts = []

    attachments.each do |attachment|
      begin
        attachment_data = @fetcher.get_attachment(message_id, attachment[:attachment_id], user_id)
        next unless attachment_data&.data

        # Decode attachment data
        begin
          decoded_data = Base64.urlsafe_decode64(attachment_data.data)
        rescue ArgumentError
          decoded_data = Base64.decode64(attachment_data.data)
        end

        # Process based on file type
        if attachment[:mime_type] == "application/pdf"
          receipt_data = @receipt_processor.process_pdf(decoded_data)
        elsif attachment[:mime_type]&.start_with?("image/")
          receipt_data = @receipt_processor.process_image(decoded_data, attachment[:filename])
        else
          next
        end

        next unless receipt_data && receipt_data[:merchant]

        # Convert to our format
        line_items = receipt_data[:line_items] || []
        primary_item = line_items.first

        receipts << {
          product_name: primary_item&.dig(:name) || "Unknown Product",
          merchant: receipt_data[:merchant],
          purchase_date: receipt_data[:purchase_date] || Date.today,
          warranty_months: determine_warranty_length(receipt_data[:merchant], primary_item&.dig(:name)),
          warranty_type: "manufacturer",
          return_policy_days: determine_return_policy(receipt_data[:merchant]),
          return_deadline: nil,
          source: "attachment_parsed",
          raw_email_id: message_id,
          order_number: receipt_data[:order_number],
          total_amount: receipt_data[:total_amount]
        }

      rescue => e
        Rails.logger.error "💥 Failed to process attachment #{attachment[:filename]}: #{e.message}"
      end
    end

    receipts
  end
end
