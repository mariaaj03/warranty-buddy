require 'rails_helper'

RSpec.describe GmailService, type: :service do
  let(:access_token) { "test_access_token" }
  let(:service) { described_class.new(access_token) }

  describe '#initialize' do
    it 'creates a new GmailService instance' do
      expect(service).to be_a(GmailService)
    end
  end

  describe '#list_messages' do
    let(:mock_gmail_service) { double('GmailService') }
    let(:mock_messages) { [double('Message', id: 'msg1'), double('Message', id: 'msg2')] }
    let(:mock_result) { double('Result', messages: mock_messages, next_page_token: nil) }

    before do
      allow(Google::Apis::GmailV1::GmailService).to receive(:new).and_return(mock_gmail_service)
      allow(mock_gmail_service).to receive(:authorization=)
      allow(mock_gmail_service).to receive(:list_user_messages).and_return(mock_result)
    end

    it 'returns a list of messages' do
      result = service.list_messages
      expect(result).to eq(mock_messages)
    end

    it 'calls list_user_messages with correct parameters' do
      service.list_messages('me', 'subject:receipt')
      expect(mock_gmail_service).to have_received(:list_user_messages).with('me', q: 'subject:receipt', page_token: nil, max_results: 100)
    end

    it 'returns empty array when no messages' do
      allow(mock_result).to receive(:messages).and_return(nil)
      result = service.list_messages
      expect(result).to eq([])
    end
  end

  describe '#get_message' do
    let(:mock_gmail_service) { double('GmailService') }
    let(:mock_message) { double('Message', id: 'msg1') }

    before do
      allow(Google::Apis::GmailV1::GmailService).to receive(:new).and_return(mock_gmail_service)
      allow(mock_gmail_service).to receive(:authorization=)
      allow(mock_gmail_service).to receive(:get_user_message).and_return(mock_message)
    end

    it 'returns a specific message' do
      result = service.get_message('msg1')
      expect(result).to eq(mock_message)
    end

    it 'calls get_user_message with correct parameters' do
      service.get_message('msg1', 'me')
      expect(mock_gmail_service).to have_received(:get_user_message).with('me', 'msg1')
    end
  end
end
