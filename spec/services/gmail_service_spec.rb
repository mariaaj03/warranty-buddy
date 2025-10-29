require 'rails_helper'

RSpec.describe GmailService do
  let(:access_token) { 'fake_access_token' }
  let(:service) { described_class.new(access_token) }
  let(:fetcher) { instance_double(GmailFetcher) }
  let(:receipt_processor) { instance_double(ReceiptProcessor) }

  before do
    allow(GmailFetcher).to receive(:new).with(access_token).and_return(fetcher)
    allow(ReceiptProcessor).to receive(:new).and_return(receipt_processor)
    allow(fetcher).to receive(:service).and_return(double(authorization: true))
  end

  describe '#parse_receipt_emails' do
    let(:message) do
      double('Message',
        id: 'msg123',
        payload: double(
          headers: [
            double(name: 'Subject', value: 'Your Amazon Order'),
            double(name: 'From', value: 'orders@amazon.com'),
            double(name: 'Date', value: '2025-10-29')
          ]
        )
      )
    end

    before do
      allow(fetcher).to receive(:list_order_messages).and_return([message])
      allow(fetcher).to receive(:get_message).and_return(message)
      allow(fetcher).to receive(:extract_html_from_message).and_return('<html>Order details</html>')
      allow(fetcher).to receive(:extract_text_from_message).and_return('Order details')
      allow(fetcher).to receive(:extract_attachments).and_return([])
      allow(receipt_processor).to receive(:cleanup)
    end

    it 'successfully parses receipt emails' do
      result = service.parse_receipt_emails
      expect(result).to be_an(Array)
    end

    it 'handles missing authorization' do
      allow(fetcher).to receive(:service).and_return(double(authorization: nil))
      expect(service.parse_receipt_emails).to eq([])
    end

    it 'handles API errors gracefully' do
      allow(fetcher).to receive(:list_order_messages).and_raise(StandardError)
      expect(service.parse_receipt_emails).to eq([])
    end
  end

  describe '#extract_merchant_from_headers' do
    it 'extracts merchant from email domain' do
      from = 'orders@amazon.com'
      result = service.send(:extract_merchant_from_headers, from, '', '')
      expect(result).to eq('Amazon')
    end

    it 'extracts merchant from sender name' do
      from = '"Best Buy" <orders@bestbuy.com>'
      result = service.send(:extract_merchant_from_headers, from, '', '')
      expect(result).to eq('Best Buy')
    end

    it 'returns nil for blank input' do
      expect(service.send(:extract_merchant_from_headers, '', '', '')).to be_nil
    end
  end

  describe '#clean_merchant_name' do
    it 'removes common prefixes and special characters' do
      name = 'noreply-orders@BestBuy (Support)'
      expect(service.send(:clean_merchant_name, name)).to eq('BestBuy')
    end

    it 'returns nil for blank input' do
      expect(service.send(:clean_merchant_name, '')).to be_nil
    end
  end

  describe '#extract_product_name_from_subject' do
    it 'extracts product name from subject patterns' do
      subject = 'Your order of iPhone 13 Pro'
      expect(service.send(:extract_product_name_from_subject, subject)).to eq('iPhone 13 Pro')
    end

    it 'returns default for blank subject' do
      expect(service.send(:extract_product_name_from_subject, '')).to eq('Unknown Product')
    end
  end

  describe '#determine_warranty_length' do
    let(:google_search_service) { instance_double(GoogleSearchService) }

    before do
      allow(GoogleSearchService).to receive(:new).and_return(google_search_service)
      allow(google_search_service).to receive(:lookup_warranty_info)
        .and_return({ warranty_months: 24 })
    end

    it 'returns default warranty for blank input' do
      expect(service.send(:determine_warranty_length, '', '')).to eq(12)
    end

    it 'uses Google Search result when available' do
      expect(service.send(:determine_warranty_length, 'Amazon', 'iPhone')).to eq(24)
    end

    it 'falls back to merchant defaults' do
      allow(google_search_service).to receive(:lookup_warranty_info).and_return(nil)
      expect(service.send(:determine_warranty_length, 'Amazon', 'Generic Product')).to eq(12)
    end

    it 'infers warranty from product type' do
      allow(google_search_service).to receive(:lookup_warranty_info).and_return(nil)
      expect(service.send(:determine_warranty_length, 'Unknown', 'refrigerator')).to eq(24)
    end
  end

  describe '#determine_return_policy' do
    it 'returns merchant-specific policy' do
      expect(service.send(:determine_return_policy, 'Amazon')).to eq(30)
    end

    it 'returns default policy for unknown merchant' do
      expect(service.send(:determine_return_policy, 'Unknown')).to eq(30)
    end

    it 'returns default policy for blank merchant' do
      expect(service.send(:determine_return_policy, '')).to eq(30)
    end
  end

  describe '#process_attachments' do
    let(:attachment) do
      {
        attachment_id: 'att123',
        mime_type: 'application/pdf',
        filename: 'receipt.pdf'
      }
    end

    let(:attachment_data) { double(data: Base64.urlsafe_encode64('fake_pdf_data')) }

    before do
      allow(fetcher).to receive(:get_attachment).and_return(attachment_data)
      allow(receipt_processor).to receive(:process_pdf)
        .and_return({ merchant: 'Amazon', line_items: [{ name: 'Test Product' }] })
    end

    it 'processes PDF attachments' do
      result = service.send(:process_attachments, [attachment], 'msg123', 'user123')
      expect(result).to be_an(Array)
      expect(result.first[:merchant]).to eq('Amazon')
    end

    it 'handles attachment processing errors' do
      allow(fetcher).to receive(:get_attachment).and_raise(StandardError)
      result = service.send(:process_attachments, [attachment], 'msg123', 'user123')
      expect(result).to eq([])
    end
  end
end