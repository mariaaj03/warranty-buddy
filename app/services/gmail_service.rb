require 'google/apis/gmail_v1'

class GmailService
  def initialize(access_token)
    @fetcher = GmailFetcher.new(access_token)
    @receipt_processor = ReceiptProcessor.new
  end

  def parse_receipt_emails(user_id = 'me')
    return [] unless @fetcher.service.authorization

    begin
      Rails.logger.info "🔍 Starting Gmail receipt parsing for user: #{user_id}"
      
      # Target major product retailers and electronics merchants
      receipt_queries = [
        'from:(amazon.com OR ebay.com OR bestbuy.com OR walmart.com OR target.com OR newegg.com OR bhphotovideo.com) subject:(order OR receipt OR shipped OR delivered OR confirmation) newer_than:2y',
        'from:(apple.com OR samsung.com OR microsoft.com OR dell.com OR hp.com OR lenovo.com) subject:(order OR receipt OR confirmation) newer_than:2y',
        'from:(costco.com OR homedepot.com OR lowes.com OR macys.com) subject:(order OR receipt) newer_than:2y'
      ]
      
      all_messages = []
      receipt_queries.each_with_index do |query, index|
        Rails.logger.info "🔎 Query #{index + 1}/#{receipt_queries.length}: #{query}"
        remaining = 100 - all_messages.length
        break if remaining <= 0
        messages = list_messages(user_id, query, remaining)
        Rails.logger.info "📧 Collected #{messages.length} messages for query #{index + 1} (capped to 100 total)"
        all_messages.concat(messages)
      end

      Rails.logger.info "📊 Total messages found: #{all_messages.length}"
      
      # Remove duplicates and let AI determine if each message is actually a receipt
      unique_messages = all_messages.uniq { |msg| msg.id }
      unique_messages = unique_messages.first(100)
      Rails.logger.info "🔄 After deduplication: #{unique_messages.length} unique messages"
      
      parsed_receipts = []
      processed_count = 0
      receipts_found = 0

      messages.each_with_index do |message, index|
        begin
          Rails.logger.info "📧 Processing message #{index + 1}/#{messages.length} (ID: #{message.id})"
          full_message = @fetcher.get_message(message.id, user_id)
          
          # Extract headers
          subject = extract_header(full_message, 'Subject') || ''
          from = extract_header(full_message, 'From') || ''
          date_header = extract_header(full_message, 'Date')
          
          Rails.logger.info "📧 Subject: '#{subject}' from #{from}"
          
          # Extract content
          html_content = @fetcher.extract_html_from_message(full_message)
          text_content = @fetcher.extract_text_from_message(full_message)
          
          # Parse the email
          parsed_receipt = parse_email_content(html_content, text_content, subject, from, date_header, full_message.id)
          processed_count += 1
          
          if parsed_receipt
            receipts_found += 1
            Rails.logger.info "✅ Parsed receipt: #{parsed_receipt[:product_name]} from #{parsed_receipt[:merchant]}"
            parsed_receipts << parsed_receipt
          else
            Rails.logger.info "❌ Not a valid receipt"
          end
          
          # Process attachments if any
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

  # List of known product/electronics retailers
  PRODUCT_MERCHANTS = %w[
    amazon
    ebay
    bestbuy
    walmart
    target
    newegg
    bhphotovideo
    apple
    samsung
    microsoft
    dell
    hp
    lenovo
    costco
    homedepot
    lowes
    macys
    adorama
    microcenter
    frys
    tigerdirect
    rakuten
    overstock
    wayfair
    etsy
    aliexpress
    banggood
    gearbest
    monoprice
    bhphoto
    adoramacamera
    crutchfield
    sony
    lg
    asus
    acer
    msi
    razer
    logitech
    corsair
    kingston
    westerndigital
    seagate
    sandisk
    crucial
    gskill
    evga
    gigabyte
    asrock
  ].freeze

  def is_product_merchant?(from_header)
    return false if from_header.blank?
    
    from_lower = from_header.downcase
    PRODUCT_MERCHANTS.any? { |merchant| from_lower.include?(merchant) }
  end

  def parse_single_receipt(message)
    # Headers and content
    subject = message.payload.headers.find { |h| h.name == 'Subject' }&.value || ''
    from    = message.payload.headers.find { |h| h.name == 'From' }&.value || ''
    date_h  = message.payload.headers.find { |h| h.name == 'Date' }&.value

    # Filter out non-product merchants
    unless is_product_merchant?(from)
      Rails.logger.info "ℹ️ Skipping non-product merchant: #{from}"
      return nil
    end

    email_content = extract_email_content(message)
    if email_content.blank?
      Rails.logger.warn "⚠️ No email content extracted from message #{message.id}"
      return nil
    end

    Rails.logger.debug "📝 Email content length: #{email_content.length} characters"
    Rails.logger.debug "📝 First 200 chars: #{email_content[0..200]}..."
  def extract_header(message, header_name)
    message.payload.headers.find { |h| h.name == header_name }&.value
  end

  def parse_email_content(html_content, text_content, subject, from, date_header, message_id)
    # First try merchant-specific parsing
    merchant = extract_merchant_from_headers(from, html_content, text_content)
    parser_class = MerchantParsers.get_parser(merchant)
    
    parsed_data = parser_class.parse(html_content, text_content)
    
    # If merchant-specific parsing failed, try generic parsing
    if parsed_data.nil?
      generic_parser = EmailOrderParser.new(html_content, text_content, subject, from)
      parsed_data = generic_parser.parse
    end
    
    return nil unless parsed_data
    
    # Convert to our expected format
    line_items = parsed_data[:line_items] || []
    primary_item = line_items.first
    
    {
      product_name: primary_item&.dig(:name) || extract_product_name_from_subject(subject),
      merchant: parsed_data[:merchant] || extract_merchant_from_headers(from, html_content, text_content),
      purchase_date: parsed_data[:purchase_date] || parse_email_date(date_header) || Date.today,
      warranty_months: determine_warranty_length(parsed_data[:merchant], primary_item&.dig(:name)),
      warranty_type: 'manufacturer',
      return_policy_days: determine_return_policy(parsed_data[:merchant]),
      return_deadline: nil,
      source: 'gmail_parsed',
      raw_email_id: message_id,
      order_number: parsed_data[:order_number],
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
        'amazon.com' => 'Amazon',
        'bestbuy.com' => 'Best Buy',
        'walmart.com' => 'Walmart',
        'target.com' => 'Target',
        'costco.com' => 'Costco',
        'newegg.com' => 'Newegg',
        'bhphotovideo.com' => 'B&H Photo'
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
    cleaned = cleaned.gsub(/\b(?:noreply|no-reply|support|orders?)\b/i, '')
    cleaned = cleaned.gsub(/[\(\)\[\]<>]/, '')
    cleaned = cleaned.gsub(/\s+/, ' ')
    cleaned.strip
  end

  def extract_product_name_from_subject(subject)
    return 'Unknown Product' if subject.blank?
    
    # Try to extract product name from subject
    patterns = [
      /receipt for\s+(.+)/i,
      /order(?:\s+for)?\s+(.+)/i,
      /your order of\s+(.+)/i,
      /purchase(?:\s+of)?\s+(.+)/i
    ]
    
    patterns.each do |pattern|
      if match = subject.match(pattern)
        return match[1].strip[0..120]
      end
    end
    
    subject.strip[0..120]
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
      'Amazon' => 12,
      'Best Buy' => 12,
      'Walmart' => 12,
      'Target' => 12,
      'Costco' => 12,
      'Apple' => 12,
      'Microsoft' => 12
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
      'Amazon' => 30,
      'Best Buy' => 15,
      'Walmart' => 90,
      'Target' => 90,
      'Costco' => 90,
      'Apple' => 14,
      'Microsoft' => 30
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
        decoded_data = Base64.urlsafe_decode64(attachment_data.data)
        
        # Process based on file type
        if attachment[:mime_type] == 'application/pdf'
          receipt_data = @receipt_processor.process_pdf(decoded_data)
        elsif attachment[:mime_type]&.start_with?('image/')
          receipt_data = @receipt_processor.process_image(decoded_data, attachment[:filename])
        else
          next
        end
        
        next unless receipt_data && receipt_data[:merchant]
        
        # Convert to our format
        line_items = receipt_data[:line_items] || []
        primary_item = line_items.first
        
        receipts << {
          product_name: primary_item&.dig(:name) || 'Unknown Product',
          merchant: receipt_data[:merchant],
          purchase_date: receipt_data[:purchase_date] || Date.today,
          warranty_months: determine_warranty_length(receipt_data[:merchant], primary_item&.dig(:name)),
          warranty_type: 'manufacturer',
          return_policy_days: determine_return_policy(receipt_data[:merchant]),
          return_deadline: nil,
          source: 'attachment_parsed',
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
