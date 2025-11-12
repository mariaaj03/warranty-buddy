require 'rails_helper'

RSpec.describe Product, type: :model do
  # Create a user for all tests that need one
  let(:user) do
    User.create!(
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123'
    )
  end

  describe 'validations' do
    it 'requires a product name' do
      product = Product.new(
        user: user,
        merchant: 'Amazon',
        purchase_date: Date.today,
        warranty_months: 12
      )
      expect(product).not_to be_valid
      expect(product.errors[:product_name]).to include("can't be blank")
    end

    it 'is valid with all required fields' do
      product = Product.new(
        user: user,
        product_name: 'MacBook Pro',
        merchant: 'Apple Store',
        purchase_date: Date.today,
        warranty_months: 12,
        gmail_uid: 'test_user_123'
      )
      expect(product).to be_valid
    end
  end

  describe '#expiry_date' do
    it 'calculates expiry date correctly' do
      product = Product.new(
        user: user,
        product_name: 'Test Product',
        purchase_date: Date.new(2024, 1, 15),
        warranty_months: 12
      )
      expect(product.expiry_date).to eq(Date.new(2025, 1, 15))
    end

    it 'handles different warranty periods' do
      product = Product.new(
        user: user,
        product_name: 'Test Product',
        purchase_date: Date.new(2024, 1, 15),
        warranty_months: 24
      )
      expect(product.expiry_date).to eq(Date.new(2026, 1, 15))
    end

    it 'returns nil when purchase_date is missing' do
      product = Product.new(
        user: user,
        product_name: 'Test Product',
        warranty_months: 12
      )
      expect(product.expiry_date).to be_nil
    end

    it 'returns nil when warranty_months is missing' do
      product = Product.new(
        user: user,
        product_name: 'Test Product',
        purchase_date: Date.today
      )
      expect(product.expiry_date).to be_nil
    end

    it 'handles month overflow correctly' do
      product = Product.new(
        user: user,
        product_name: 'Test Product',
        purchase_date: Date.new(2024, 11, 15),
        warranty_months: 3
      )
      expect(product.expiry_date).to eq(Date.new(2025, 2, 15))
    end
  end

  describe 'factory' do
    it 'creates a valid product' do
      # Update the factory to include a user, or create one explicitly
      product = build(:product, user: user)
      expect(product).to be_valid
    end
  end
end
