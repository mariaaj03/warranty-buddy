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
    get dashboard_path # use dashboard_path explicitly
    expect(response).to redirect_to(new_user_session_path)
  end

  it "renders the dashboard when signed in (gmail not connected)" do
    sign_in user
    allow(user).to receive(:gmail_connected?).and_return(false)

    get dashboard_path
    expect(response).to have_http_status(:ok)

    expect(response.body).to include("Warranty Buddy")   # page title/text
    expect(response.body).to include("Not Connected")    # status text you expect
  end

  it "renders the dashboard when signed in (gmail connected)" do
    sign_in user
    allow(user).to receive(:gmail_connected?).and_return(true)

    get dashboard_path
    expect(response).to have_http_status(:ok)
    # add any connected-state text you show in the view, e.g.:
    # expect(response.body).to include("Connected")
  end
end
