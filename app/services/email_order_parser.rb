require "nokogiri"
require "date"

begin
  require "chronic"
rescue LoadError => e
  Rails.logger.warn "Chronic gem not available: #{e.message}"
end

class EmailOrderParser
  def initialize(html_content, text_content = nil, subject = nil, from = nil)
    @html = (html_content || "").to_s.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace)
    @text = (text_content || extract_text_from_html(@html)).to_s.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace)
    @subject = (subject || "").to_s.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace)
    @from = (from || "").to_s.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace)
    @doc = Nokogiri::HTML(@html)
  end

  def parse
    return nil unless is_order_email?

    {
      merchant: extract_merchant,
      order_number: extract_order_number,
      purchase_date: extract_purchase_date,
      line_items: extract_line_items,
      total_amount: extract_total_amount
    }
  end

  def is_order_email?
    promotional_keywords = [
      /select items to arrive/i, /last minute gifts/i, /gifts delivered today/i,
      /newsletter/i, /marketing/i, /advertisement/i, /unsubscribe/i
    ]
    
    return false if promotional_keywords.any? { |pattern| @subject.match?(pattern) }
    
    return false if @subject.match?(/^(select items|shop now|buy now|save now|deal of|special offer)/i)
    
    has_order_number = extract_order_number.present?
    has_line_items = extract_line_items.any?
    has_total = extract_total_amount.present?
    
    subject_keywords = %w[order receipt invoice confirmation shipped delivered tracking e-receipt]
    has_receipt_subject = subject_keywords.any? { |keyword| @subject.downcase.include?(keyword) }
    
    if has_receipt_subject
      return true if has_order_number || has_line_items || has_total
    end
    
    if @subject.match?(/your (receipt|e-receipt) from/i) || @subject.match?(/receipt for/i)
      return true if has_order_number || has_line_items || has_total
    end
    
    return false unless has_order_number || (has_line_items && has_total)
    
    content_indicators = [
      /order\s+(?:number|#|id)[:\s]+[A-Z0-9\-]{6,}/i,
      /receipt\s+(?:number|#)/i,
      /invoice\s+(?:number|#)/i,
      /confirmation\s+(?:number|#)/i,
      /tracking\s+(?:number|#)/i,
      /total[:\s]*\$?\d+\.?\d*/i,
      /subtotal[:\s]*\$?\d+\.?\d*/i
    ]

    content_indicators.any? { |pattern| @text.match?(pattern) }
  end

  def extract_merchant
    # Try structured meta tags first
    site = @doc.at('meta[property="og:site_name"]')&.[]("content")
    return clean_merchant_name(site) if site.present?

    # Extract from sender email domain
    domain_merchant = extract_merchant_from_domain(@from)
    return domain_merchant if domain_merchant.present?

    # Look for merchant name in content
    merchant_patterns = [
      /(?:sold by|seller|merchant|store|from)\s*[:\-]?\s*([^\n\r]{2,80})/i,
      /order from\s+([^\n\r]{2,80})/i,
      /thank you for your order from\s+([^\n\r]{2,80})/i
    ]

    merchant_patterns.each do |pattern|
      if match = @text.match(pattern)
        return clean_merchant_name(match[1])
      end
    end

    # Fallback to common merchant names in text
    common_merchants = %w[Amazon Best\s+Buy Walmart Target Costco Newegg B&H\s+Photo Apple Microsoft]
    common_merchants.find { |merchant| @text.match?(/#{merchant}/i) }&.gsub(/\s+/, " ")
  end

  def extract_order_number
    order_patterns = [
      /order\s*(?:number|#|id)[:\s]*([A-Z0-9\-]{6,40})/i,
      /order\s*[:\s]*([A-Z0-9\-]{6,40})/i,
      /confirmation\s*(?:number|#)[:\s]*([A-Z0-9\-]{6,40})/i,
      /invoice\s*(?:number|#)[:\s]*([A-Z0-9\-]{6,40})/i,
      /receipt\s*(?:number|#)[:\s]*([A-Z0-9\-]{6,40})/i
    ]

    order_patterns.each do |pattern|
      if match = @text.match(pattern)
        return match[1].strip
      end
    end

    nil
  end

  def extract_purchase_date
    # Look for explicit date patterns
    date_patterns = [
      /(?:order date|purchase date|date of purchase)[:\s]*([A-Za-z0-9, \-\/]+)/i,
      /placed on[:\s]*([A-Za-z0-9, \-\/]+)/i,
      /ordered on[:\s]*([A-Za-z0-9, \-\/]+)/i,
      /purchased on[:\s]*([A-Za-z0-9, \-\/]+)/i
    ]

    date_patterns.each do |pattern|
      if match = @text.match(pattern)
        parsed_date = parse_date(match[1])
        return parsed_date if parsed_date
      end
    end

    # Look for dates near order number
    if order_number = extract_order_number
      order_context = extract_context_around_pattern(@text, /#{Regexp.escape(order_number)}/i, 200)
      date_in_context = extract_date_from_text(order_context)
      return date_in_context if date_in_context
    end

    # Look for dates in table headers or near totals
    table_dates = extract_dates_from_tables
    return table_dates.first if table_dates.any?

    nil
  end

  def extract_line_items
    items = []

    # Try to extract from structured tables first
    table_items = extract_items_from_tables
    return table_items if table_items.any?

    # Fallback to regex patterns for line items
    line_item_patterns = [
      /(\d+)x?\s+(.{3,80}?)\s*[-–]\s*\$?([0-9\.,]+)/i,
      /(.{3,80}?)\s*[-–]\s*\$?([0-9\.,]+)/i
    ]

    line_item_patterns.each do |pattern|
      @text.scan(pattern).each do |match|
        qty = match[0]&.to_i || 1
        name = match[1]&.strip
        price = match[2]&.strip

        next if name.blank? || name.length < 3

        items << {
          name: name,
          quantity: qty,
          price: parse_price(price)
        }
      end
    end

    items.uniq { |item| item[:name] }
  end

  def extract_total_amount
    total_patterns = [
      /total[:\s]*\$?([0-9\.,]+)/i,
      /grand total[:\s]*\$?([0-9\.,]+)/i,
      /amount due[:\s]*\$?([0-9\.,]+)/i,
      /order total[:\s]*\$?([0-9\.,]+)/i
    ]

    total_patterns.each do |pattern|
      if match = @text.match(pattern)
        return parse_price(match[1])
      end
    end

    nil
  end


  private

  def extract_text_from_html(html)
    return "" if html.blank?
    doc = Nokogiri::HTML(html)
    doc.text
  end

  def clean_merchant_name(name)
    return "" if name.blank?

    cleaned = name.strip
    cleaned = cleaned.gsub(/\b(?:noreply|no-reply|support|orders?)\b/i, "")
    cleaned = cleaned.gsub(/[\(\)\[\]<>@\-\.]+/, " ")  # Remove special characters
    cleaned = cleaned.gsub(/\s+/, " ")
    cleaned.strip
  end

  def extract_merchant_from_domain(from_header)
    return "" if from_header.blank?

    email_match = from_header.match(/[\w.+-]+@([\w.-]+)/)
    return "" unless email_match

    domain = email_match[1].downcase
    domain_mapping = {
      "amazon.com" => "Amazon",
      "bestbuy.com" => "Best Buy",
      "walmart.com" => "Walmart",
      "target.com" => "Target",
      "costco.com" => "Costco"
    }

    domain_mapping[domain] || domain.split(".").first.capitalize
  end

  def parse_date(date_string)
    return nil if date_string.blank?

    # Try Chronic first for natural language parsing (if available)
    if defined?(Chronic)
      parsed = Chronic.parse(date_string)
      return parsed.to_date if parsed
    end

    # Fallback to Date.parse
    Date.parse(date_string)
  rescue ArgumentError, TypeError
    nil
  end

  def extract_date_from_text(text)
    return nil if text.blank?

    # Look for various date formats
    date_patterns = [
      /\b(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})\b/,
      /\b(\d{4}[\/\-]\d{1,2}[\/\-]\d{1,2})\b/,
      /\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},?\s+\d{4}\b/i,
      /\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\.?\s+\d{1,2},?\s+\d{4}\b/i
    ]

    date_patterns.each do |pattern|
      if match = text.match(pattern)
        parsed_date = parse_date(match[1])
        return parsed_date if parsed_date
      end
    end

    nil
  end

  def extract_context_around_pattern(text, pattern, context_length)
    if match = text.match(pattern)
      start_pos = [ match.begin(0) - context_length, 0 ].max
      end_pos = [ match.end(0) + context_length, text.length ].min
      text[start_pos...end_pos]
    else
      ""
    end
  end

  def extract_dates_from_tables
    dates = []

    @doc.css("table").each do |table|
      table.css("th, td").each do |cell|
        text = cell.text.strip
        parsed_date = extract_date_from_text(text)
        dates << parsed_date if parsed_date
      end
    end

    dates.uniq.compact
  end

  def extract_items_from_tables
    items = []

    @doc.css("table").each do |table|
      headers = table.css("th").map { |th| th.text.strip.downcase }

      # Check if this looks like an order items table
      next unless (headers & [ "item", "description", "product", "qty", "quantity", "price", "amount" ]).any?

      table.css("tr").each do |row|
        cells = row.css("td").map { |td| td.text.strip }
        next if cells.empty? || cells.length < 2

        # Try to identify columns
        name_col = find_column_index(headers, [ "item", "description", "product" ])
        qty_col = find_column_index(headers, [ "qty", "quantity" ])
        price_col = find_column_index(headers, [ "price", "amount", "total" ])

        next unless name_col && cells[name_col].present?

        name = cells[name_col]
        quantity = qty_col ? (cells[qty_col].to_i rescue 1) : 1
        price = price_col ? parse_price(cells[price_col]) : nil

        items << {
          name: name,
          quantity: quantity,
          price: price
        }
      end
    end

    items
  end

  def find_column_index(headers, keywords)
    headers.each_with_index do |header, index|
      return index if keywords.any? { |keyword| header.include?(keyword) }
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
