# spec/requests/dashboard_request_spec.rb
require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) do
    User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  it "redirects to sign-in when not authenticated" do
    get dashboard_path
    expect(response).to redirect_to(new_user_session_path)
  end

  it "renders the dashboard when signed in (gmail not connected)" do
    sign_in user
    allow_any_instance_of(User).to receive(:gmail_connected?).and_return(false)

    get dashboard_path
    expect(response).to have_http_status(:ok)
    # Just check that we get a response with some content
    expect(response.body).to be_present
  end

  it "renders the dashboard when signed in (gmail connected)" do
    sign_in user
    allow_any_instance_of(User).to receive(:gmail_connected?).and_return(true)

    get dashboard_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to be_present
  end
end
