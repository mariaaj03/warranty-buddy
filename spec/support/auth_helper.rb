module AuthHelper
  def mock_gmail_connection
    allow_any_instance_of(DashboardController).to receive(:set_gmail_status)
    allow_any_instance_of(DashboardController).to receive(:instance_variable_get)
      .with(:@gmail_connected).and_return(true)
    allow(session).to receive(:[]).with(:gmail_token).and_return('fake_token')
    allow(session).to receive(:[]).with(:gmail_uid).and_return('test_user')
  end
end