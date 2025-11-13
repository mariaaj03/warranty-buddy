# Helper methods for Gmail service step definitions

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

