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
    result = parser.parse
    expect(result).to include(
      merchant: "Amazon",
      order_number: "12345",
      purchase_date: nil, # No date in the example
      line_items: [],
      total_amount: 99.99
    )
  end

  it 'returns nil if the email is not an order email' do
    invalid_parser = described_class.new("", "", "Random Subject", "")
    expect(invalid_parser.parse).to be_nil
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
    parser = described_class.new("", "Thank you for your order from Walmart.", "", "")
    expect(parser.extract_merchant).to eq("Walmart")
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
    parser = described_class.new("", "1x Widget - $19.99\n2x Gadget - $39.98", "", "")
    expect(parser.extract_line_items).to contain_exactly(
      { name: "Widget", quantity: 1, price: 19.99 },
      { name: "Gadget", quantity: 2, price: 39.98 }
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

end