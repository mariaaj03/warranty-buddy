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

  # Helper method to create mock Gmail messages
  def create_mock_gmail_message(id:, subject: "", from: "", date: "", html_content: "", text_content: "")
    mock_message = double("GmailMessage", id: id)
    
    # Create mock headers
    mock_subject_header = double("Header", name: "Subject", value: subject)
    mock_from_header = double("Header", name: "From", value: from)
    mock_date_header = double("Header", name: "Date", value: date)
    
    mock_headers = [mock_subject_header, mock_from_header, mock_date_header]
    
    # Create mock payload
    mock_payload = double("Payload", headers: mock_headers)
    
    # Set up the message to return the payload
    allow(mock_message).to receive(:payload).and_return(mock_payload)
    allow(mock_message).to receive(:html_content).and_return(html_content)
    allow(mock_message).to receive(:text_content).and_return(text_content)
    
    mock_message
  end
end

World(TestHelpers)
