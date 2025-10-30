RSpec.shared_context 'gmail_connected' do
  before do
    mock_gmail_connection
    allow(session).to receive(:[]).with(:gmail_token).and_return('fake_token')
    allow(session).to receive(:[]).with(:gmail_uid).and_return('test_user')
  end
end