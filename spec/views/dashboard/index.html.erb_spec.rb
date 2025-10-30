require 'rails_helper'

RSpec.describe "dashboard/index", type: :view do
  before do
    assign(:title, "Warranty Buddy - Iteration 1")
    assign(:subtitle, "Your Digital Memory for Every Purchase")
    assign(:warranties, [])
    assign(:gmail_connected, false)
    assign(:gmail_messages, [])
    assign(:search_term, nil)
    assign(:status_filter, nil)
    assign(:merchant_filter, nil)
    assign(:sort_by, 'expiry_date')
    assign(:merchants, [])
  end

  it "displays the title and subtitle" do
    render
    expect(rendered).to have_selector('h1', text: "Warranty Buddy - Iteration 1")
    expect(rendered).to have_selector('.muted', text: "Your Digital Memory for Every Purchase")
  end

  it "shows not connected status when Gmail is not connected" do
    render
    expect(rendered).to have_selector('.badge.not', text: "Not Connected")
    expect(rendered).to have_button("Connect Gmail", class: "btn-primary")
  end

  it "shows connected status when Gmail is connected" do
    assign(:gmail_connected, true)
    render
    expect(rendered).to have_selector('.badge.ok', text: "Connected")
    expect(rendered).to have_button("Disconnect Gmail", class: "btn-danger")
  end

  it "displays the add product warranty section" do
    render
    within('details') do
      expect(rendered).to have_selector('summary', text: "Add a product warranty")
      expect(rendered).to have_field('product', type: 'text')
      expect(rendered).to have_field('merchant', type: 'text')
      expect(rendered).to have_field('purchase_date', type: 'date')
      expect(rendered).to have_field('warranty_length', type: 'number')
    end
  end

  it "shows empty warranties table when no products" do
    render
    within('table') do
      expect(rendered).to have_selector('td', text: "No warranties yet.")
    end
  end

  context "with products" do
    let(:product) do
      create(:product,
        product_name: "Test Product",
        merchant: "Amazon",
        purchase_date: Date.today,
        warranty_months: 12,
        gmail_uid: 'test_user'
      )
    end

    before do
      assign(:warranties, [ product ])
    end

    it "displays products in the table" do
      render
      within('table') do
        expect(rendered).to have_selector('td', text: "Test Product")
        expect(rendered).to have_selector('td', text: "Amazon")
      end
    end

    it "shows active status for current warranty" do
      render
      within('table') do
        expect(rendered).to have_selector('.status-badge.status-active', text: "Active")
      end
    end

    it "shows expired status for old warranty" do
      expired_product = create(:product,
        product_name: "Old Product",
        purchase_date: 2.years.ago,
        warranty_months: 12,
        gmail_uid: 'test_user'
      )
      assign(:warranties, [expired_product])
      render
      within('table') do
        expect(rendered).to have_selector('.status-badge.status-expired', text: "Expired")
      end
    end
  end
end

