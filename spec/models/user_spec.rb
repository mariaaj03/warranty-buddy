require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it 'has many products' do
      expect(described_class.reflect_on_association(:products).macro).to eq(:has_many)
    end

    it 'destroys associated products when user is destroyed' do
      user = User.create!(
        email: 'test@example.com',
        password: 'password123',
        password_confirmation: 'password123'
      )
      
      product = user.products.create!(
        product_name: 'Test Product',
        merchant: 'Test Store',
        purchase_date: Date.today
      )
      
      expect { user.destroy }.to change(Product, :count).by(-1)
    end
  end

  describe 'devise modules' do
    it 'includes database_authenticatable' do
      expect(User.devise_modules).to include(:database_authenticatable)
    end

    it 'includes registerable' do
      expect(User.devise_modules).to include(:registerable)
    end

    it 'includes recoverable' do
      expect(User.devise_modules).to include(:recoverable)
    end

    it 'includes rememberable' do
      expect(User.devise_modules).to include(:rememberable)
    end

    it 'includes validatable' do
      expect(User.devise_modules).to include(:validatable)
    end

    it 'includes omniauthable' do
      expect(User.devise_modules).to include(:omniauthable)
    end

    it 'has google_oauth2 as omniauth provider' do
      expect(User.omniauth_providers).to include(:google_oauth2)
    end
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      user = User.new(
        email: 'test@example.com',
        password: 'password123',
        password_confirmation: 'password123'
      )
      expect(user).to be_valid
    end

    it 'requires an email' do
      user = User.new(password: 'password123', password_confirmation: 'password123')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it 'requires a valid email format' do
      user = User.new(
        email: 'invalid-email',
        password: 'password123',
        password_confirmation: 'password123'
      )
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('is invalid')
    end

    it 'requires email to be unique' do
      User.create!(
        email: 'test@example.com',
        password: 'password123',
        password_confirmation: 'password123'
      )
      
      duplicate_user = User.new(
        email: 'test@example.com',
        password: 'different123',
        password_confirmation: 'different123'
      )
      
      expect(duplicate_user).not_to be_valid
      expect(duplicate_user.errors[:email]).to include('has already been taken')
    end

    it 'requires a password' do
      user = User.new(email: 'test@example.com')
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("can't be blank")
    end

    it 'requires password to be at least 6 characters' do
      user = User.new(
        email: 'test@example.com',
        password: '12345',
        password_confirmation: '12345'
      )
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include('is too short (minimum is 6 characters)')
    end

    it 'requires password confirmation to match' do
      user = User.new(
        email: 'test@example.com',
        password: 'password123',
        password_confirmation: 'different123'
      )
      expect(user).not_to be_valid
      expect(user.errors[:password_confirmation]).to include("doesn't match Password")
    end
  end

  describe '.from_omniauth' do
    let(:auth_hash) do
      double('auth', 
        provider: 'google_oauth2',
        uid: '123456789',
        info: double('info',
          email: 'oauth@example.com',
          name: 'OAuth User',
          image: 'https://example.com/avatar.jpg'
        )
      )
    end

    context 'when user does not exist' do


      it 'generates a random password for oauth users' do
        allow(Devise).to receive(:friendly_token).and_return('randomtoken123456789')
        
        user = User.from_omniauth(auth_hash)
        expect(user.encrypted_password).to be_present
      end

      it 'saves the user successfully' do
        user = User.from_omniauth(auth_hash)
        expect(user).to be_persisted
        expect(user.new_record?).to be false
      end
    end

    context 'when user already exists' do
      let!(:existing_user) do
        User.create!(
          provider: 'google_oauth2',
          uid: '123456789',
          email: 'oauth@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          name: 'Old Name',
          image: 'https://example.com/old-avatar.jpg'
        )
      end

      it 'finds the existing user' do
        expect {
          User.from_omniauth(auth_hash)
        }.not_to change(User, :count)
      end

      it 'updates the existing user with new oauth data' do
        user = User.from_omniauth(auth_hash)
        
        expect(user.id).to eq(existing_user.id)
        expect(user.name).to eq('OAuth User')
        expect(user.image).to eq('https://example.com/avatar.jpg')
        expect(user.email).to eq('oauth@example.com') # Should remain the same
      end

      it 'does not change the email of existing user' do
        original_email = existing_user.email
        user = User.from_omniauth(auth_hash)
        expect(user.email).to eq(original_email)
      end

      it 'returns the updated user' do
        user = User.from_omniauth(auth_hash)
        expect(user).to eq(existing_user)
      end
    end

    context 'with different provider but same uid' do
      let(:different_auth_hash) do
        double('auth', 
          provider: 'facebook',
          uid: '123456789',
          info: double('info',
            email: 'facebook@example.com',
            name: 'Facebook User',
            image: 'https://facebook.com/avatar.jpg'
          )
        )
      end

      it 'creates a different user for different provider' do
        User.from_omniauth(auth_hash) # Create google user
        
        expect {
          User.from_omniauth(different_auth_hash)
        }.to change(User, :count).by(1)
        
        users = User.all
        expect(users.map(&:provider)).to match_array(['google_oauth2', 'facebook'])
      end
    end

    context 'when oauth data is missing' do
      let(:incomplete_auth_hash) do
        double('auth', 
          provider: 'google_oauth2',
          uid: '123456789',
          info: double('info',
            email: nil,
            name: 'No Email User',
            image: 'https://example.com/avatar.jpg'
          )
        )
      end

      it 'handles missing email gracefully' do
        user = User.from_omniauth(incomplete_auth_hash)
        expect(user.email).to be_nil
        expect(user.persisted?).to be false # Should fail validation
      end
    end
  end

  describe '#gmail_connected?' do
    let(:user) do
      User.create!(
        email: 'test@example.com',
        password: 'password123',
        password_confirmation: 'password123'
      )
    end

    context 'when gmail_token is present' do
      it 'returns true' do
        user.update(gmail_token: 'valid_token_123')
        expect(user.gmail_connected?).to be true
      end

      it 'returns true even with empty string that is not blank' do
        user.update(gmail_token: 'token')
        expect(user.gmail_connected?).to be true
      end
    end

    context 'when gmail_token is not present' do
      it 'returns false when gmail_token is nil' do
        user.update(gmail_token: nil)
        expect(user.gmail_connected?).to be false
      end

      it 'returns false when gmail_token is empty string' do
        user.update(gmail_token: '')
        expect(user.gmail_connected?).to be false
      end

      it 'returns false when gmail_token is whitespace' do
        user.update(gmail_token: '   ')
        expect(user.gmail_connected?).to be false
      end

      it 'returns false for new user without gmail_token set' do
        new_user = User.new(
          email: 'new@example.com',
          password: 'password123'
        )
        expect(new_user.gmail_connected?).to be false
      end
    end
  end

  describe 'database columns' do
    it 'has expected columns' do
      expect(User.column_names).to include('email')
      expect(User.column_names).to include('encrypted_password')
      expect(User.column_names).to include('provider')
      expect(User.column_names).to include('uid')
      expect(User.column_names).to include('name')
      expect(User.column_names).to include('image')
      expect(User.column_names).to include('gmail_token')
    end
  end
end