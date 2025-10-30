require 'rails_helper'

RSpec.describe GmailFetcher do
  let(:access_token) { 'fake_access_token' }
  let(:fetcher) { described_class.new(access_token) }
  let(:gmail_service) { instance_double(Google::Apis::GmailV1::GmailService) }

  before do
    allow(Google::Apis::GmailV1::GmailService).to receive(:new).and_return(gmail_service)
    allow(gmail_service).to receive(:authorization=).with(access_token)
  end

  describe '#list_order_messages' do
    let(:message1) { double('Message', id: 'msg1') }
    let(:message2) { double('Message', id: 'msg2') }
    let(:response) { double('Response', messages: [ message1, message2 ], next_page_token: nil) }

    before do
      allow(gmail_service).to receive(:list_user_messages).and_return(response)
    end

    it 'fetches messages using multiple queries' do
      result = fetcher.list_order_messages
      expect(result).to contain_exactly(message1, message2)
      expect(gmail_service).to have_received(:list_user_messages).at_least(:once)
    end

    it 'removes duplicate messages' do
      duplicate_response = double('Response', messages: [ message1, message1, message2 ], next_page_token: nil)
      allow(gmail_service).to receive(:list_user_messages).and_return(duplicate_response)

      result = fetcher.list_order_messages
      expect(result.length).to eq(2)
    end

    it 'respects max_results parameter' do
      result = fetcher.list_order_messages('me', 1)
      expect(result.length).to eq(1)
    end

    it 'handles empty response' do
      allow(gmail_service).to receive(:list_user_messages)
        .and_return(double('Response', messages: nil, next_page_token: nil))

      result = fetcher.list_order_messages
      expect(result).to be_empty
    end
  end

  describe '#get_message' do
    let(:message) { double('Message') }

    it 'retrieves a specific message' do
      allow(gmail_service).to receive(:get_user_message)
        .with('me', 'msg1', format: 'full')
        .and_return(message)

      result = fetcher.get_message('msg1')
      expect(result).to eq(message)
    end
  end

  describe '#extract_html_from_message' do
    let(:html_content) { '<html><body>Test</body></html>' }
    let(:encoded_html) { Base64.urlsafe_encode64(html_content) }

    it 'extracts HTML from message body' do
      message = double('Message',
        payload: double('Payload',
          body: double('Body', data: encoded_html),
          parts: nil
        )
      )

      result = fetcher.extract_html_from_message(message)
      expect(result).to eq(html_content)
    end

    it 'extracts HTML from message parts' do
      html_part = double('Part',
        mime_type: 'text/html',
        body: double('Body', data: encoded_html),
        parts: nil
      )
      message = double('Message',
        payload: double('Payload',
          body: nil,
          parts: [ html_part ]
        )
      )

      result = fetcher.extract_html_from_message(message)
      expect(result).to eq(html_content)
    end

    it 'returns empty string when no HTML content found' do
      message = double('Message',
        payload: double('Payload',
          body: nil,
          parts: []
        )
      )

      result = fetcher.extract_html_from_message(message)
      expect(result).to eq('')
    end
  end

  describe '#extract_text_from_message' do
    let(:text_content) { 'Plain text content' }
    let(:encoded_text) { Base64.urlsafe_encode64(text_content) }

    it 'extracts text from message body' do
      message = double('Message',
        payload: double('Payload',
          body: double('Body', data: encoded_text),
          parts: nil
        )
      )

      result = fetcher.extract_text_from_message(message)
      expect(result).to eq(text_content)
    end

    it 'extracts text from message parts' do
      text_part = double('Part',
        mime_type: 'text/plain',
        body: double('Body', data: encoded_text),
        parts: nil
      )
      message = double('Message',
        payload: double('Payload',
          body: nil,
          parts: [ text_part ]
        )
      )

      result = fetcher.extract_text_from_message(message)
      expect(result).to eq(text_content)
    end
  end

  describe '#extract_attachments' do
    let(:attachment) do
      double('Part',
        filename: 'receipt.pdf',
        body: double('Body', attachment_id: 'att1'),
        mime_type: 'application/pdf',
        parts: nil
      )
    end

    it 'extracts attachments from message parts' do
      message = double('Message',
        payload: double('Payload',
          parts: [ attachment ]
        )
      )

      result = fetcher.extract_attachments(message)
      expect(result).to contain_exactly(
        hash_including(
          filename: 'receipt.pdf',
          attachment_id: 'att1',
          mime_type: 'application/pdf'
        )
      )
    end

    it 'handles nested attachments' do
      nested_part = double('Part',
        parts: [ attachment ],
        filename: nil,
        body: nil
      )
      message = double('Message',
        payload: double('Payload',
          parts: [ nested_part ]
        )
      )

      result = fetcher.extract_attachments(message)
      expect(result.length).to eq(1)
    end

    it 'returns empty array for messages without attachments' do
      message = double('Message',
        payload: double('Payload',
          parts: []
        )
      )

      result = fetcher.extract_attachments(message)
      expect(result).to be_empty
    end
  end

  describe '#get_attachment' do
    let(:attachment) { double('Attachment') }

    it 'retrieves a specific attachment' do
      allow(gmail_service).to receive(:get_user_message_attachment)
        .with('me', 'msg1', 'att1')
        .and_return(attachment)

      result = fetcher.get_attachment('msg1', 'att1')
      expect(result).to eq(attachment)
    end
  end
end
