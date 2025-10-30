module TestHelpers
  def mock_gmail_connection
    # Mock the session to simulate Gmail connection
    allow_any_instance_of(ActionController::TestRequest).to receive(:session).and_return({
      gmail_uid: "test_user_123",
      gmail_token: "test_token_123"
    })
  end

  def clear_gmail_connection
    # Clear the session to simulate no Gmail connection
    allow_any_instance_of(ActionController::TestRequest).to receive(:session).and_return({})
  end
end

World(TestHelpers)
