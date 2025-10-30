require 'rails_helper'

RSpec.describe "Dashboard", type: :request do
  describe "GET /" do
    it "returns http success" do
      get root_path
      expect(response).to have_http_status(:success)
    end

    it "displays the warranty buddy title" do
      get root_path
      expect(response.body).to include("Warranty Buddy")
    end

    it "shows not connected status when Gmail is not connected" do
      get root_path
      expect(response.body).to include("Not Connected")
    end

  end
end
  
