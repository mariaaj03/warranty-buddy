require 'rails_helper'

RSpec.describe EmailOrderParser, type: :service do
  let(:html_content) { "<html><body>Thank you for your order from Amazon</body></html>" }
  let(:text_content) { "Thank you for your order from Amazon. Order #12345. Total: $99.99." }
  let(:subject) { "Your Amazon Order Confirmation" }
  let(:from) { "orders@amazon.com" }
  let(:parser) { described_class.new(html_content, text_content, subject, from) }

  describe '#initialize' do
    it 'initializes with HTML, text, subject, and from' do
      expect(parser.instance_variable_get(:@html)).to eq(html_content)
      expect(parser.instance_variable_get(:@text)).to eq(text_content)
      expect(parser.instance_variable_get(:@subject)).to eq(subject)
      expect(parser.instance_variable_get(:@from)).to eq(from)
    end
  end

  describe '#parse' do
    it 'returns a hash with parsed order details' do
      parser = described_class.new(
        "<p>Order from Amazon</p>",
        "Order #12345\nTotal: $99.99",
        "Amazon Order",
        "store@amazon.com"
      )
      
      result = parser.parse
      expect(result).to include(
        merchant: "Amazon",
        order_number: "12345"
      )
    end
  end

  describe '#extract_merchant' do
    it 'extracts merchant from meta tags' do
      html = '<meta property="og:site_name" content="Amazon">'
      parser = described_class.new(html, "", "", "")
      expect(parser.extract_merchant).to eq("Amazon")
    end

    it 'extracts merchant from email domain' do
      parser = described_class.new("", "", "", "orders@amazon.com")
      expect(parser.extract_merchant).to eq("Amazon")
    end

    it 'extracts merchant from content' do
      text = "Thank you for your order from Best Buy Store"
      parser = described_class.new("", text, "", "")
      expect(parser.extract_merchant).to eq("Best Buy Store")
    end

    it 'returns nil if no merchant is found' do
      parser = described_class.new("", "", "", "")
      expect(parser.extract_merchant).to be_nil
    end
  end

  describe '#extract_purchase_date' do
    it 'extracts purchase date from content' do
      parser = described_class.new("", "Order Date: October 29, 2025", "", "")
      expect(parser.extract_purchase_date).to eq(Date.parse("2025-10-29"))
    end

    it 'returns nil if no date is found' do
      expect(parser.extract_purchase_date).to be_nil
    end
  end

  describe '#extract_line_items' do
    it 'extracts line items from content' do
      text = "1x Test Product - $19.99"
      parser = described_class.new("", text, "", "")
      items = parser.extract_line_items
      
      expect(items).to contain_exactly(
        { name: "Test Product", quantity: 1, price: 19.99 }
      )
    end

    it 'returns an empty array if no line items are found' do
      expect(parser.extract_line_items).to eq([])
    end
  end

  describe '#extract_total_amount' do
    it 'extracts total amount from content' do
      expect(parser.extract_total_amount).to eq(99.99)
    end

    it 'returns nil if no total amount is found' do
      parser = described_class.new("", "No total here.", "", "")
      expect(parser.extract_total_amount).to be_nil
    end
  end

  describe '#extract_text_from_html' do
    it 'extracts text from HTML content' do
      html = '<html><body>Hello <b>World</b></body></html>'
      result = parser.send(:extract_text_from_html, html)
      expect(result).to eq('Hello World')
    end

    it 'returns empty string for blank HTML' do
      expect(parser.send(:extract_text_from_html, '')).to eq('')
      expect(parser.send(:extract_text_from_html, nil)).to eq('')
    end

    it 'handles malformed HTML' do
      result = parser.send(:extract_text_from_html, '<div>Unclosed div')
      expect(result).to eq('Unclosed div')
    end
  end

  describe '#clean_merchant_name' do
    it 'removes common prefixes and special characters' do
      examples = {
        'orders@amazon.com' => 'amazon.com',
        'noreply@bestbuy.com' => 'bestbuy.com'
      }

      examples.each do |input, expected|
        result = parser.send(:clean_merchant_name, input)
        expect(result).to eq(expected)
      end
    end

    it 'returns empty string for blank input' do
      expect(parser.send(:clean_merchant_name, '')).to eq('')
      expect(parser.send(:clean_merchant_name, nil)).to eq('')
    end
  end

  describe '#extract_merchant_from_domain' do
    it 'extracts merchant from common email domains' do
      examples = {
        'orders@amazon.com' => 'Amazon',
        'support@bestbuy.com' => 'Best Buy',
        'noreply@walmart.com' => 'Walmart',
        'orders@target.com' => 'Target'
      }

      examples.each do |email, expected|
        expect(parser.send(:extract_merchant_from_domain, email)).to eq(expected)
      end
    end

    it 'returns empty string for invalid email format' do
      expect(parser.send(:extract_merchant_from_domain, 'invalid-email')).to eq('')
    end

    it 'returns empty string for blank input' do
      expect(parser.send(:extract_merchant_from_domain, '')).to eq('')
      expect(parser.send(:extract_merchant_from_domain, nil)).to eq('')
    end
  end

  describe '#extract_items_from_tables' do
    let(:table_html) do
      <<-HTML
        <table>
          <tr>
            <th>Product</th>
            <th>Qty</th>
            <th>Price</th>
          </tr>
          <tr>
            <td>Widget Pro</td>
            <td>2</td>
            <td>$29.99</td>
          </tr>
        </table>
      HTML
    end

    it 'extracts items from HTML tables' do
      parser = described_class.new(table_html, '', '', '')
      result = parser.send(:extract_items_from_tables)
      expect(result).to contain_exactly(
        { name: 'Widget Pro', quantity: 2, price: 29.99 }
      )
    end

    it 'handles tables without headers' do
      html = '<table><tr><td>Not a product table</td></tr></table>'
      parser = described_class.new(html, '', '', '')
      expect(parser.send(:extract_items_from_tables)).to eq([])
    end

    it 'handles missing price or quantity columns' do
      html = <<-HTML
        <table>
          <tr><th>Product</th></tr>
          <tr><td>Widget</td></tr>
        </table>
      HTML
      parser = described_class.new(html, '', '', '')
      expect(parser.send(:extract_items_from_tables)).to eq([])
    end
  end

  describe '#parse_price' do
    it 'parses various price formats' do
      {
        '$99.99' => 99.99,
        '99.99' => 99.99,
        '$1,234.56' => 1234.56
      }.each do |input, expected|
        result = parser.send(:parse_price, input)
        expect(result).to eq(expected)
      end
    end

    it 'returns nil for invalid price formats' do
      ['invalid', '', nil].each do |invalid_price|
        expect(parser.send(:parse_price, invalid_price)).to be_nil
      end
    end
  end

  describe '#is_order_email?' do
    it 'identifies order emails by subject keywords' do
      keywords = [ 'order', 'receipt', 'invoice', 'confirmation', 'shipped', 'delivered' ]
      keywords.each do |keyword|
        parser = described_class.new('', '', "Your #{keyword}", '')
        expect(parser.is_order_email?).to be true
      end
    end

    it 'identifies order emails by content patterns' do
      patterns = [
        'Order #123456',
        'Receipt ID: ABC123',
        'Invoice Number: INV-123',
        'Total: $99.99',
        'Subtotal: $89.99'
      ]
      patterns.each do |content|
        parser = described_class.new('', content, '', '')
        expect(parser.is_order_email?).to be true
      end
    end

    it 'returns false for non-order emails' do
      parser = described_class.new('', 'Regular newsletter content', 'Newsletter', '')
      expect(parser.is_order_email?).to be false
    end
  end

  describe '#parse_date' do
    it 'parses various date formats' do
      dates = {
        '2025-10-29' => Date.new(2025, 10, 29),
        '10/29/2025' => Date.new(2025, 10, 29),
        'October 29, 2025' => Date.new(2025, 10, 29),
        'Oct 29 2025' => Date.new(2025, 10, 29)
      }

      dates.each do |input, expected|
        result = parser.send(:parse_date, input)
        expect(result).to eq(expected)
      end
    end

    it 'returns nil for invalid dates' do
      expect(parser.send(:parse_date, 'invalid')).to be_nil
      expect(parser.send(:parse_date, nil)).to be_nil
    end
  end

  describe '#extract_dates_from_tables' do
    it 'extracts dates from table cells' do
      html = '<table><tr><td>2025-10-29</td></tr></table>'
      parser = described_class.new(html)
      dates = parser.send(:extract_dates_from_tables)
      expect(dates).to contain_exactly(Date.new(2025, 10, 29))
    end

    it 'returns empty array when no tables found' do
      parser = described_class.new('<div>No tables here</div>')
      expect(parser.send(:extract_dates_from_tables)).to be_empty
    end
  end

  describe '#extract_items_from_tables' do
    it 'extracts items from structured tables' do
      html = <<-HTML
        <table>
          <tr>
            <th>Item</th>
            <th>Quantity</th>
            <th>Price</th>
          </tr>
          <tr>
            <td>Test Product</td>
            <td>2</td>
            <td>$19.99</td>
          </tr>
        </table>
      HTML
      parser = described_class.new(html)
      items = parser.send(:extract_items_from_tables)
      expect(items).to contain_exactly(
        { name: 'Test Product', quantity: 2, price: 19.99 }
      )
    end

    it 'handles tables without proper headers' do
      html = '<table><tr><td>Not a product table</td></tr></table>'
      parser = described_class.new(html)
      expect(parser.send(:extract_items_from_tables)).to be_empty
    end
  end

  describe '#find_column_index' do
    it 'finds column index by keywords' do
      headers = [ 'item name', 'quantity', 'price' ]
      result = parser.send(:find_column_index, headers, [ 'item', 'product' ])
      expect(result).to eq(0)
    end

    it 'returns nil when keyword not found' do
      headers = [ 'item name', 'quantity', 'price' ]
      result = parser.send(:find_column_index, headers, [ 'notfound' ])
      expect(result).to be_nil
    end
  end

  describe '#parse_price' do
    it 'parses various price formats' do
      expect(parser.send(:parse_price, '$99.99')).to eq(99.99)
      expect(parser.send(:parse_price, '99,99')).to eq(99.99)
      expect(parser.send(:parse_price, '1,999.99')).to eq(1999.99)
      expect(parser.send(:parse_price, '1.999,99')).to eq(1999.99)
    end

    it 'handles invalid price strings' do
      expect(parser.send(:parse_price, 'invalid')).to be_nil
      expect(parser.send(:parse_price, nil)).to be_nil
      expect(parser.send(:parse_price, '')).to be_nil
    end
  end
end
