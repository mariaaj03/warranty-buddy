require 'google/apis/gmail_v1'
require 'mail'
require 'time'

class GmailService
  Gmail = Google::Apis::GmailV1

  def initialize(access_token)
    @service = Gmail::GmailService.new
    @service.authorization = access_token
    @ai_service = AiService.new
  end

  def list_messages(user_id = 'me', query = '', max_total = 100)
    messages = []
    page_token = nil
    begin
      remaining = [max_total - messages.length, 100].min
      break if remaining <= 0
      result = @service.list_user_messages(user_id, q: query, page_token: page_token, max_results: remaining)
      messages.concat(result.messages || [])
      page_token = result.next_page_token
    end while page_token.present? && messages.length < max_total
    messages
  end

  def get_message(message_id, user_id = 'me')
    @service.get_user_message(user_id, message_id)
  end

  def parse_receipt_emails(user_id = 'me')
    # Return empty array if no valid token
    return [] unless @service.authorization

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
      ai_processed = 0
      ai_receipts_found = 0

      unique_messages.each_with_index do |message, index|
        begin
          Rails.logger.info "🤖 Processing message #{index + 1}/#{unique_messages.length} (ID: #{message.id})"
          full_message = get_message(message.id, user_id)
          
          # Log basic message info for debugging
          subject = full_message.payload.headers.find { |h| h.name == 'Subject' }&.value || 'No Subject'
          from = full_message.payload.headers.find { |h| h.name == 'From' }&.value || 'Unknown Sender'
          Rails.logger.info "📧 Message: '#{subject}' from #{from}"
          
          parsed_receipt = parse_single_receipt(full_message)
          ai_processed += 1
          
          if parsed_receipt
            ai_receipts_found += 1
            Rails.logger.info "✅ AI identified as receipt: #{parsed_receipt[:product_name]} from #{parsed_receipt[:merchant]} (confidence: #{parsed_receipt[:confidence]})"
            parsed_receipts << parsed_receipt
          else
            Rails.logger.info "❌ AI determined this is not a receipt"
          end
        rescue => e
          Rails.logger.error "💥 Failed to parse message #{message.id}: #{e.message}"
        end
      end

      Rails.logger.info "🎯 Final Results: #{ai_processed} messages processed by AI, #{ai_receipts_found} receipts found, #{parsed_receipts.length} total receipts"
      parsed_receipts
    rescue => e
      Rails.logger.error "💥 Gmail API error: #{e.message}"
      []
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

    # Heuristic: decide if likely a purchase receipt without AI
    unless likely_receipt_email?(subject, email_content)
      Rails.logger.info "ℹ️ Heuristics: not a likely receipt"
      return nil
    end

    merchant = extract_merchant_from_body(email_content) || extract_merchant(from)
    purchase_date = safe_parse_email_date(date_h) || Date.today
    product_name = extract_product_name(subject, email_content)

    # Use AI to look up warranty information for this specific product
    Rails.logger.info "🔍 Looking up warranty info for: #{product_name}"
    warranty_info = @ai_service.lookup_warranty_info(product_name, merchant, email_content)
    
    warranty_months = nil
    warranty_type = nil
    return_policy_days = nil
    
    if warranty_info
      warranty_months = warranty_info['warranty_months']
      warranty_type = warranty_info['warranty_type']
      return_policy_days = warranty_info['return_policy_days']
      Rails.logger.info "✅ Found warranty: #{warranty_months} months (#{warranty_type})"
    else
      Rails.logger.warn "⚠️ No warranty info found, using default 12 months"
      warranty_months = 12  # Default to 1 year if AI lookup fails
      warranty_type = 'manufacturer'
    end

    {
      product_name: product_name,
      merchant: merchant,
      purchase_date: purchase_date,
      warranty_months: warranty_months,
      warranty_type: warranty_type,
      return_policy_days: return_policy_days,
      return_deadline: nil,
      confidence: 0.6,
      source: 'gmail_ai_warranty',
      raw_email_id: message.id
    }
  end

  def extract_email_content(message)
    # Determine encoding of a part from headers
    def part_encoding(part)
      enc = part.headers&.find { |h| h.name&.downcase == 'content-transfer-encoding' }&.value&.downcase
      enc&.strip
    end

    # Decode a part's body data according to its encoding; be permissive
    def decode_part_data(part)
      data = part.body&.data
      return "" unless data

      encoding = part_encoding(part)

      case encoding
      when 'base64'
        begin
          return Base64.urlsafe_decode64(data)
        rescue ArgumentError
          begin
            return Base64.decode64(data)
          rescue
            # fall through
          end
        end
      when 'quoted-printable'
        begin
          return Mail::Encodings::QuotedPrintable.decode(data)
        rescue
          # fall through
        end
      when '7bit'
        # 7bit is already ASCII, return as-is
        return data
      end

      # Heuristics if no/unknown encoding header
      # If it looks like already-decoded HTML/text, return as-is
      return data if data.lstrip.start_with?('<!DOCTYPE', '<html', '<div', '<p', 'Subject:', 'From:', 'Hi all,', 'Dear')

      # Try urlsafe then strict base64; if both fail, return original
      begin
        Base64.urlsafe_decode64(data)
      rescue ArgumentError
        begin
          Base64.decode64(data)
        rescue
          data
        end
      end
    end

    # Recursively walk parts to find text content
    def collect_text_from_part(part)
      texts = []
      if part.parts && !part.parts.empty?
        part.parts.each { |p| texts.concat(collect_text_from_part(p)) }
      else
        if part.mime_type == 'text/plain' || part.mime_type == 'text/html'
          decoded = decode_part_data(part)
          texts << decoded if decoded.present?
        end
      end
      texts
    end

    raw_texts = []
    if message.payload&.parts&.any?
      message.payload.parts.each { |p| raw_texts.concat(collect_text_from_part(p)) }
    elsif message.payload&.body&.data
      # Synthesize a part-like object to reuse decoding logic
      synthetic_part = Google::Apis::GmailV1::MessagePart.new(
        mime_type: message.payload.mime_type,
        headers: message.payload.headers,
        body: message.payload.body
      )
      raw_texts << decode_part_data(synthetic_part)
    end

    content = raw_texts.join("\n\n")

    # Clean up HTML if present
    if content.include?('<')
      doc = Nokogiri::HTML(content)
      content = doc.text
    end

    content.strip
  end

  # ---------- Heuristic helpers (no AI) ----------
  def likely_receipt_email?(subject, content)
    s = (subject || '').downcase
    c = (content || '').downcase
    keywords = %w[receipt order purchase invoice confirmation shipped delivered tracking paid payment]
    # Must match at least one keyword in subject or first 2k of content
    return true if keywords.any? { |k| s.include?(k) }
    return keywords.any? { |k| c[0..2000].to_s.include?(k) }
  end

  def extract_merchant(from_header)
    # Examples: "Amazon.com <order-update@amazon.com>" or "noreply@bestbuy.com"
    return '' if from_header.blank?
    name_match = from_header.match(/\A\s*"?([^"<]+?)"?\s*<[^>]+>\s*\z/)
    if name_match
      name = name_match[1].to_s.strip
      return sanitize_merchant_name(name)
    end
    email_match = from_header.match(/[\w.+-]+@([\w.-]+)/)
    domain = email_match && email_match[1]
    return domain_to_merchant(domain) if domain
    sanitize_merchant_name(from_header)
  end

  def sanitize_merchant_name(name)
    cleaned = name.gsub(/(^\s+|\s+$)/, '')
    cleaned = cleaned.gsub(/\bnoreply\b|\bno-reply\b|\bsupport\b|\borders?\b/i, '').strip
    cleaned = cleaned.gsub(/[\(\)\[\]<>]/, '').strip
    cleaned.squeeze(' ')
  end

  def domain_to_merchant(domain)
    host = domain.to_s.downcase
    # Take second-level label (amazon.com -> amazon)
    label = host.split('.').reject { |p| %w[com net org co io ai app email info store shop gov edu].include?(p) }.first || host.split('.').first
    label.to_s.gsub('-', ' ').split.map(&:capitalize).join(' ')
  end

  def safe_parse_email_date(date_str)
    return nil if date_str.blank?
    Time.parse(date_str).to_date
  rescue ArgumentError
    nil
  end

  def extract_product_name(subject, content)
    # 1) Look for explicit item/product lines in body
    body = content.to_s
    if (m = body.match(/^(?:item|product)\s*[:\-]\s*(.+)$/i))
      return m[1].strip[0..120]
    end
    if (m = body.match(/\b(?:model|sku)\s*[:\-]\s*([\w\- ]{3,})/i))
      return m[1].strip[0..120]
    end
    # 2) Subject-based patterns
    subj = subject.to_s
    [
      /receipt for\s+(.+)/i,
      /order(?:\s+for)?\s+(.+)/i,
      /your order of\s+(.+)/i,
      /purchase(?:\s+of)?\s+(.+)/i
    ].each do |rx|
      if (m = subj.match(rx))
        return m[1].strip[0..120]
      end
    end
    # 3) Fallback to trimmed subject
    subj.strip[0..120]
  end

  def extract_merchant_from_body(content)
    body = content.to_s
    # Common patterns: Sold by, Seller, Merchant, Store, From
    if (m = body.match(/\b(?:sold by|seller|merchant|store|from)\b\s*[:\-]?\s*([^\n\r]{2,80})/i))
      candidate = m[1].strip
      # Trim trailing phrases
      candidate = candidate.gsub(/\s*(inc\.|llc|ltd|co\.|corp\.)\.?\s*$/i, '').strip
      return candidate[0..80]
    end
    # Look for "Thank you for your order from <Merchant>"
    if (m = body.match(/order from\s+([^\n\r]{2,80})/i))
      return m[1].strip[0..80]
    end
    nil
  end

  def parse_date(date_string)
    return Date.today unless date_string
    
    Date.parse(date_string)
  rescue ArgumentError
    Date.today
  end
end
