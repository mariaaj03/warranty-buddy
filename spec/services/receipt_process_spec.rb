require 'rails_helper'

RSpec.describe ReceiptProcessor do
  let(:processor) { described_class.new }

  after do
    processor.cleanup
  end

  describe '#process_pdf' do
    let(:pdf_reader) { instance_double(PDF::Reader) }
    let(:page) { double('Page', text: 'Sample receipt from Amazon\nTotal: $99.99') }

    before do
      stub_const('PDF::Reader', class_double('PDF::Reader'))
      allow(PDF::Reader).to receive(:new).and_return(pdf_reader)
      allow(pdf_reader).to receive(:pages).and_return([ page ])
    end

    it 'processes PDF data successfully' do
      result = processor.process_pdf('fake_pdf_data')
      expect(result).to include(
        merchant: 'Amazon',
        total_amount: 99.99
      )
    end

    it 'returns nil when PDF data is blank' do
      expect(processor.process_pdf(nil)).to be_nil
    end

    it 'handles PDF processing errors gracefully' do
      allow(PDF::Reader).to receive(:new).and_raise(StandardError)
      expect(processor.process_pdf('invalid_pdf_data')).to be_nil
    end
  end

  describe '#process_image' do
    let(:rtesseract) { instance_double(RTesseract) }

    before do
      stub_const('RTesseract', class_double('RTesseract'))
      allow(RTesseract).to receive(:new).and_return(rtesseract)
      allow(rtesseract).to receive(:to_s).and_return('Receipt from Best Buy\nTotal: $199.99')
    end

    it 'returns nil when image data is blank' do
      expect(processor.process_image(nil)).to be_nil
    end

    it 'handles OCR processing errors gracefully' do
      allow(RTesseract).to receive(:new).and_raise(StandardError)
      expect(processor.process_image('invalid_image_data')).to be_nil
    end
  end

  describe '#determine_image_extension' do
    it 'returns correct extension for known image types' do
      expect(processor.send(:determine_image_extension, 'image.jpg')).to eq('.jpg')
      expect(processor.send(:determine_image_extension, 'image.png')).to eq('.png')
      expect(processor.send(:determine_image_extension, 'image.gif')).to eq('.gif')
    end

    it 'returns .jpg for unknown extensions' do
      expect(processor.send(:determine_image_extension, 'image.xyz')).to eq('.jpg')
    end

    it 'returns .jpg when filename is nil' do
      expect(processor.send(:determine_image_extension, nil)).to be_nil
    end
  end

  describe '#extract_merchant_from_receipt' do

    it 'extracts merchant from thank you message' do
      text = 'Thank you for shopping at Custom Store'
      expect(processor.send(:extract_merchant_from_receipt, text)).to eq('Custom Store')
    end

    it 'extracts merchant from store label' do
      text = 'Store: Local Shop'
      expect(processor.send(:extract_merchant_from_receipt, text)).to eq('Local Shop')
    end

    it 'returns nil when no merchant found' do
      expect(processor.send(:extract_merchant_from_receipt, 'No merchant here')).to be_nil
    end
  end

  describe '#extract_date_from_receipt' do

    it 'returns nil for invalid dates' do
      expect(processor.send(:extract_date_from_receipt, 'Invalid date')).to be_nil
    end
  end

  describe '#extract_items_from_receipt' do

    it 'extracts items without quantities' do
      text = 'Gadget Basic 19.99'
      items = processor.send(:extract_items_from_receipt, text)
      expect(items).to contain_exactly(
        { name: 'Gadget Basic', quantity: 1, price: 19.99 }
      )
    end

    it 'deduplicates items by name' do
      text = "Widget Pro 29.99\nWidget Pro 29.99"
      items = processor.send(:extract_items_from_receipt, text)
      expect(items.length).to eq(1)
    end
  end

  describe '#extract_total_from_receipt' do
    it 'extracts total amount in various formats' do
      expect(processor.send(:extract_total_from_receipt, 'Total: $99.99')).to eq(99.99)
      expect(processor.send(:extract_total_from_receipt, 'Grand Total: 99.99')).to eq(99.99)
      expect(processor.send(:extract_total_from_receipt, 'Amount Due: $99.99')).to eq(99.99)
    end

    it 'returns nil when no total found' do
      expect(processor.send(:extract_total_from_receipt, 'No total here')).to be_nil
    end
  end

  describe '#extract_order_number_from_receipt' do
    it 'extracts order numbers in various formats' do
      expect(processor.send(:extract_order_number_from_receipt, 'Order #: ABC-123456')).to eq('ABC-123456')
      expect(processor.send(:extract_order_number_from_receipt, 'Order Number: XYZ123')).to eq('XYZ123')
      expect(processor.send(:extract_order_number_from_receipt, 'Receipt #: 987654')).to eq('987654')
    end

    it 'returns nil when no order number found' do
      expect(processor.send(:extract_order_number_from_receipt, 'No order number')).to be_nil
    end
  end

  describe '#parse_price' do
    it 'parses prices with different formats' do
      expect(processor.send(:parse_price, '$99.99')).to eq(99.99)
      expect(processor.send(:parse_price, '99,99')).to eq(99.99)
      expect(processor.send(:parse_price, '1,999.99')).to eq(1999.99)
    end

    it 'returns nil for invalid price strings' do
      expect(processor.send(:parse_price, 'invalid')).to be_nil
      expect(processor.send(:parse_price, nil)).to be_nil
    end
  end

  describe '#cleanup' do

    it 'handles cleanup errors gracefully' do
      temp_file = processor.send(:create_temp_file, 'test data', '.txt')
      allow(temp_file).to receive(:unlink).and_raise(StandardError)
      expect { processor.cleanup }.not_to raise_error
    end
  end
end
