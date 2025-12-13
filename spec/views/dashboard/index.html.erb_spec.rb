require 'rails_helper'

RSpec.describe "dashboard/index", type: :view do
  include Devise::Test::ControllerHelpers

  let(:user) { 
    create(:user, 
      uid: 'test_user',
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123'
    ) 
  }

  before do
    # Sign in the user for Devise
    sign_in user
    
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

  it "displays the dashboard header with logo" do
    render
    expect(rendered).to have_selector('.logo', text: "Warranty Buddy")
    expect(rendered).to have_selector('.logo-icon svg')
  end

  it "shows user information in header" do
    render
    expect(rendered).to have_selector('.user-name', text: user.email)
    expect(rendered).to have_button("Sign Out")
  end

  it "displays the filters section" do
    render
    expect(rendered).to have_selector('.filters-section')
    expect(rendered).to have_field('search')
    expect(rendered).to have_select('status')
    expect(rendered).to have_select('merchant')
    expect(rendered).to have_select('sort')
  end

  it "displays the add product warranty section" do
    render
    within('.add-product-section') do
      expect(rendered).to have_selector('summary', text: "Add a Product Warranty")
      expect(rendered).to have_field('product', type: 'text')
      expect(rendered).to have_field('merchant', type: 'text')
      expect(rendered).to have_field('purchase_date', type: 'date')
      expect(rendered).to have_field('warranty_length', type: 'number')
    end
  end

  it "shows empty warranties table when no products" do
    render
    within('.warranties-section') do
      expect(rendered).to have_selector('.empty-state')
      expect(rendered).to have_text("No warranties yet.")
    end
  end

  context "with products" do
    let(:product) do
      create(:product,
        product_name: "Test Product",
        merchant: "Amazon",
        purchase_date: Date.today,
        warranty_months: 12,
        user: user
      )
    end

    before do
      assign(:warranties, [ product ])
    end

    it "displays products in the table" do
      render
      within('.warranties-table') do
        expect(rendered).to have_selector('.product-name', text: "Test Product")
        expect(rendered).to have_text("Amazon")
      end
    end

    it "shows active status for current warranty" do
      render
      within('.warranties-table') do
        expect(rendered).to have_selector('.status-badge.status-active', text: "Active")
      end
    end

    it "shows expired status for old warranty" do
      expired_product = create(:product,
        product_name: "Old Product",
        purchase_date: 2.years.ago,
        warranty_months: 12,
        user: user
      )
      assign(:warranties, [expired_product])
      render
      within('.warranties-table') do
        expect(rendered).to have_selector('.status-badge.status-expired', text: "Expired")
      end
    end
  end

  it "displays export section" do
    render
    within('.export-section') do
      expect(rendered).to have_text("Export Warranties")
      expect(rendered).to have_link("Export CSV")
      expect(rendered).to have_link("Export iCal")
    end
  end
end

