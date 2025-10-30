require 'rails_helper'

RSpec.describe "dashboard/index", type: :view do
  before do
    assign(:title, "Warranty Buddy - Iteration 1")
    assign(:subtitle, "Your Digital Memory for Every Purchase")
    assign(:warranties, [])
    assign(:gmail_connected, false)
    assign(:gmail_messages, [])
  end

  it "displays the title and subtitle" do
    render
    expect(rendered).to include("Warranty Buddy - Iteration 1")
    expect(rendered).to include("Your Digital Memory for Every Purchase")
  end

  it "shows not connected status when Gmail is not connected" do
    render
    expect(rendered).to include("Not Connected")
    expect(rendered).to have_button("Connect Gmail")
  end

  it "shows connected status when Gmail is connected" do
    assign(:gmail_connected, true)
    render
    expect(rendered).to include("Connected")
    expect(rendered).to have_button("Disconnect Gmail")
  end

  it "displays the add product warranty section" do
    render
    expect(rendered).to include("Add a product warranty")
    expect(rendered).to include('name="product"')
    expect(rendered).to include('name="merchant"')
    expect(rendered).to include('name="purchase_date"')
    expect(rendered).to include('name="warranty_length"')
  end

  it "shows empty warranties table when no products" do
    render
    expect(rendered).to include("Please connect your Gmail account to view warranties.")
  end

  context "with products" do
    let(:product) { create(:product, product_name: "Test Product", merchant: "Amazon") }

    before do
      assign(:warranties, [ product ])
    end

    it "displays products in the table" do
      render
      expect(rendered).to include("Test Product")
      expect(rendered).to include("Amazon")
    end

    it "shows active status for current warranty" do
      render
      expect(rendered).to include("Active")
    end

    it "shows expired status for old warranty" do
      expired_product = create(:product, :expired, product_name: "Old Product")
      assign(:warranties, [ expired_product ])
      render
      expect(rendered).to include("Expired")
    end
  end

  it "has proper form structure" do
    render
    expect(rendered).to include('action="/upload"')
    expect(rendered).to include('method="post"')
    expect(rendered).to include('name="product"')
    expect(rendered).to include('name="merchant"')
    expect(rendered).to include('name="purchase_date"')
    expect(rendered).to include('name="warranty_length"')
    expect(rendered).to include("Add a product warranty")
  end
end
