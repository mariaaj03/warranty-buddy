class MerchantParsers
  class AmazonParser
    def self.parse(html_content, text_content)
      doc = Nokogiri::HTML(html_content)

      {
        merchant: "Amazon",
        order_number: extract_order_number(doc, text_content),
        purchase_date: extract_purchase_date(doc, text_content),
        line_items: extract_line_items(doc),
        total_amount: extract_total_amount(doc, text_content)
      }
    end

    private

    def self.extract_order_number(doc, text)
      # Amazon order number patterns
      patterns = [
        /order\s*#\s*([0-9]{3}-[0-9]{7}-[0-9]{7})/i,
        /order\s*number[:\s]*([0-9]{3}-[0-9]{7}-[0-9]{7})/i
      ]

      patterns.each do |pattern|
        if match = text.match(pattern)
          return match[1]
        end
      end

      nil
    end

    def self.extract_purchase_date(doc, text)
      # Look for "Ordered on" or "Placed on" patterns
      patterns = [
        /ordered on[:\s]*([A-Za-z0-9, \-\/]+)/i,
        /placed on[:\s]*([A-Za-z0-9, \-\/]+)/i
      ]

      patterns.each do |pattern|
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

    def self.extract_line_items(doc)
      items = []

      # Look for Amazon's product table structure
      doc.css("table").each do |table|
        table.css("tr").each do |row|
          cells = row.css("td")
          next if cells.length < 3

          # Look for product name in first cell
          product_cell = cells.first
          product_name = product_cell.text.strip

          # Skip if it looks like a header
          next if product_name.match?(/^(item|product|description)$/i)

          # Look for quantity and price in other cells
          qty = 1
          price = nil

          cells.each do |cell|
            cell_text = cell.text.strip
            if cell_text.match?(/^\d+$/)
              qty = cell_text.to_i
            elsif cell_text.match?(/^\$?[0-9\.,]+$/)
              price = parse_price(cell_text)
            end
          end

          if product_name.length > 3
            items << {
              name: product_name,
              quantity: qty,
              price: price
            }
          end
        end
      end

      items
    end

    def self.extract_total_amount(doc, text)
      patterns = [
        /order total[:\s]*\$?([0-9\.,]+)/i,
        /total[:\s]*\$?([0-9\.,]+)/i
      ]

      patterns.each do |pattern|
        if match = text.match(pattern)
          return parse_price(match[1])
        end
      end

      nil
    end

    def self.parse_price(price_string)
      return nil if price_string.blank?
      cleaned = price_string.gsub(/[^\d\.,]/, "")
      return nil if cleaned.blank?

      # Handle US format with thousands separator: 1,234.56
      if cleaned.match(/^\d{1,3}(\,\d{3})+\.\d{2}$/)
        cleaned = cleaned.gsub(",", "")
      elsif cleaned.count(".") > 1
        # Multiple dots, assume thousands separator
        cleaned = cleaned.gsub(".", "")
      end

      cleaned.to_f
    rescue
      nil
    end
  end

  class BestBuyParser
    def self.parse(html_content, text_content)
      doc = Nokogiri::HTML(html_content)

      {
        merchant: "Best Buy",
        order_number: extract_order_number(doc, text_content),
        purchase_date: extract_purchase_date(doc, text_content),
        line_items: extract_line_items(doc),
        total_amount: extract_total_amount(doc, text_content)
      }
    end

    private

    def self.extract_order_number(doc, text)
      patterns = [
        /order\s*#\s*([A-Z0-9\-]{8,20})/i,
        /order\s*number[:\s]*([A-Z0-9\-]{8,20})/i
      ]

      patterns.each do |pattern|
        if match = text.match(pattern)
          return match[1]
        end
      end

      nil
    end

    def self.extract_purchase_date(doc, text)
      patterns = [
        /order\s*date[:\s]*([A-Za-z0-9, \-\/]+)/i,
        /purchased on[:\s]*([A-Za-z0-9, \-\/]+)/i
      ]

      patterns.each do |pattern|
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

    def self.extract_line_items(doc)
      items = []

      # Best Buy uses specific table structures
      doc.css("table").each do |table|
        table.css("tr").each do |row|
          cells = row.css("td")
          next if cells.length < 2

          product_name = cells.first.text.strip
          next if product_name.length < 3
          next if product_name.match?(/^(item|product|description)$/i)

          # Look for price in other cells
          price = nil
          cells.each do |cell|
            cell_text = cell.text.strip
            if cell_text.match?(/^\$?[0-9\.,]+$/)
              price = parse_price(cell_text)
              break
            end
          end

          items << {
            name: product_name,
            quantity: 1,
            price: price
          }
        end
      end

      items
    end

    def self.extract_total_amount(doc, text)
      patterns = [
        /order\s*total[:\s]*\$?([0-9\.,]+)/i,
        /total[:\s]*\$?([0-9\.,]+)/i
      ]

      patterns.each do |pattern|
        if match = text.match(pattern)
          return parse_price(match[1])
        end
      end

      nil
    end

    def self.parse_price(price_string)
      return nil if price_string.blank?
      cleaned = price_string.gsub(/[^\d\.,]/, "")
      return nil if cleaned.blank?

      # Handle US format with thousands separator: 1,234.56
      if cleaned.match(/^\d{1,3}(\,\d{3})+\.\d{2}$/)
        cleaned = cleaned.gsub(",", "")
      elsif cleaned.count(".") > 1
        # Multiple dots, assume thousands separator
        cleaned = cleaned.gsub(".", "")
      end

      cleaned.to_f
    rescue
      nil
    end
  end

  class GenericParser
    def self.parse(html_content, text_content)
      # Use the general EmailOrderParser for unknown merchants
      parser = EmailOrderParser.new(html_content, text_content)
      result = parser.parse

      if result
      end

      result
    end
  end

  def self.get_parser(merchant)
    case merchant&.downcase
    when "amazon"
      AmazonParser
    when "best buy"
      BestBuyParser
    else
      GenericParser
    end
  end
end
