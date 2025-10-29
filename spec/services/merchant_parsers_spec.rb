require 'rails_helper'

RSpec.describe MerchantParsers do
  let(:html_content) { "<html><body>Thank you for your order from Amazon</body></html>" }
  let(:text_content) { "Thank you for your order from Amazon. Order #123-4567890-1234567. Total: $99.99." }

  describe '.get_parser' do
    it 'returns the AmazonParser for Amazon' do
      parser = described_class.get_parser('Amazon')
      expect(parser).to eq(MerchantParsers::AmazonParser)
    end

    it 'returns the BestBuyParser for Best Buy' do
      parser = described_class.get_parser('Best Buy')
      expect(parser).to eq(MerchantParsers::BestBuyParser)
    end

    it 'returns the GenericParser for unknown merchants' do
      parser = described_class.get_parser('Unknown Merchant')
      expect(parser).to eq(MerchantParsers::GenericParser)
    end
  end
end
RSpec.describe MerchantParsers::AmazonParser do
    let(:html_content) { "<html><body>Thank you for your order from Amazon</body></html>" }
    let(:text_content) { "Thank you for your order from Amazon. Order #123-4567890-1234567. Ordered on: October 29, 2025. Total: $99.99." }
  
    describe '.parse' do
      it 'parses the order details correctly' do
        result = described_class.parse(html_content, text_content)
        expect(result).to include(
          merchant: 'Amazon',
          order_number: '123-4567890-1234567',
          purchase_date: Date.parse('2025-10-29'),
          total_amount: 99.99
        )
        expect(result[:line_items]).to be_an(Array)
      end
    end
        describe '.extract_total_amount' do
      it 'extracts the total amount from text content' do
        doc = Nokogiri::HTML(html_content)
        result = described_class.send(:extract_total_amount, doc, text_content)
        expect(result).to eq(99.99)
      end
    
      it 'returns nil if no total amount is found' do
        doc = Nokogiri::HTML(html_content)
        result = described_class.send(:extract_total_amount, doc, "No total here.")
        expect(result).to be_nil
      end
    end
    describe '.extract_line_items' do
        let(:html_with_table) do
          <<-HTML
            <html>
              <body>
                <table>
                  <tr><td>Widget</td><td>1</td><td>$19.99</td></tr>
                  <tr><td>Gadget</td><td>2</td><td>$39.98</td></tr>
                </table>
              </body>
            </html>
          HTML
        end
      
        it 'extracts line items from the HTML content' do
          doc = Nokogiri::HTML(html_with_table)
          result = described_class.send(:extract_line_items, doc)
          expect(result).to contain_exactly(
            { name: 'Widget', quantity: 1, price: 19.99 },
            { name: 'Gadget', quantity: 2, price: 39.98 }
          )
        end
      
        it 'returns an empty array if no line items are found' do
          doc = Nokogiri::HTML("<html><body>No items here.</body></html>")
          result = described_class.send(:extract_line_items, doc)
          expect(result).to eq([])
        end
      end
  end

  RSpec.describe MerchantParsers::GenericParser do
    let(:html_content) { "<html><body>Generic order email</body></html>" }
    let(:text_content) { "Order #12345. Total: $49.99." }
  
    describe '.parse' do
      it 'delegates parsing to EmailOrderParser' do
        parser = instance_double(EmailOrderParser)
        allow(EmailOrderParser).to receive(:new).with(html_content, text_content).and_return(parser)
        allow(parser).to receive(:parse).and_return({ merchant: 'Generic', order_number: '12345', total_amount: 49.99 })
  
        result = described_class.parse(html_content, text_content)
        expect(result).to include(
          merchant: 'Generic',
          order_number: '12345',
          total_amount: 49.99
        )
      end
    end
  end