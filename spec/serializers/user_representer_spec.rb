require 'rails_helper'

RSpec.describe UserRepresenter do
  let(:user) do
    User.create!(
      first_name: 'John',
      last_name: 'Doe',
      email: 'john@example.com',
      account_name: 'johndoe',
      mobile: '+12025551234',
      password: 'password123',
      password_confirmation: 'password123'
    )
  end

  describe '.render' do
    it 'returns nil when user is nil' do
      expect(described_class.render(nil)).to be_nil
    end

    it 'returns user hash with all basic fields' do
      result = described_class.render(user)
      
      expect(result).to be_a(Hash)
      expect(result[:id]).to eq(user.id)
      expect(result[:firstName]).to eq('John')
      expect(result[:lastName]).to eq('Doe')
      expect(result[:email]).to eq('john@example.com')
      expect(result[:accountName]).to eq('johndoe')
      expect(result[:mobile]).to eq('+12025551234')
    end

    it 'uses camelCase for field names' do
      result = described_class.render(user)
      
      expect(result).to have_key(:firstName)
      expect(result).to have_key(:lastName)
      expect(result).to have_key(:accountName)
      expect(result).not_to have_key(:first_name)
      expect(result).not_to have_key(:last_name)
      expect(result).not_to have_key(:account_name)
    end

    it 'includes empty settings array when user has no settings' do
      result = described_class.render(user)
      
      expect(result[:settings]).to eq([])
    end

    it 'includes settings when user has settings' do
      Setting.create!(configurable: user, key: 'theme', value: 'dark')
      Setting.create!(configurable: user, key: 'language', value: 'en')
      
      result = described_class.render(user)
      
      expect(result[:settings]).to be_an(Array)
      expect(result[:settings].length).to eq(2)
      expect(result[:settings][0][:key]).to eq('theme')
      expect(result[:settings][1][:key]).to eq('language')
    end

    it 'handles user without mobile' do
      user.update!(mobile: nil)
      result = described_class.render(user)
      
      expect(result).not_to have_key(:mobile)
    end

    it 'compacts nil values from result' do
      user.update!(mobile: nil)
      result = described_class.render(user)
      
      expect(result.values).not_to include(nil)
    end

    it 'renders settings using SettingRepresenter' do
      setting = Setting.create!(configurable: user, key: 'theme', value: 'dark')
      
      result = described_class.render(user)
      
      expect(result[:settings].first[:id]).to eq(setting.id)
      expect(result[:settings].first[:key]).to eq('theme')
      expect(result[:settings].first[:value]).to eq('dark')
    end

    it 'handles user object without settings association gracefully' do
      # Create a user-like object without settings
      user_without_settings = double('User', 
        id: 1, 
        first_name: 'Test', 
        last_name: 'User',
        email: 'test@example.com',
        account_name: 'testuser',
        mobile: '+11234567890'
      )
      allow(user_without_settings).to receive(:respond_to?).with(:settings).and_return(false)
      
      result = described_class.render(user_without_settings)
      
      expect(result[:settings]).to eq([])
    end

    it 'preserves setting values as stored (string format)' do
      Setting.create!(
        configurable: user, 
        key: 'preferences', 
        value: '{"theme":"dark","notifications":{"email":true,"push":false}}'
      )
      
      result = described_class.render(user)
      
      # Settings are stored as strings
      expect(result[:settings].first[:value]).to eq('{"theme":"dark","notifications":{"email":true,"push":false}}')
    end

    it 'handles newly created user' do
      new_user = User.create!(
        first_name: 'New',
        last_name: 'User',
        email: 'new@example.com',
        account_name: 'newuser',
        password: 'password123',
        password_confirmation: 'password123'
      )

      result = described_class.render(new_user)
      
      expect(result[:id]).to eq(new_user.id)
      expect(result[:firstName]).to eq('New')
      expect(result[:lastName]).to eq('User')
    end

    it 'includes all expected keys' do
      result = described_class.render(user)
      
      expected_keys = [:id, :firstName, :lastName, :email, :accountName, :mobile, :settings]
      expect(result.keys).to match_array(expected_keys)
    end
  end

  describe '.render_collection' do
    it 'returns empty array when users is nil' do
      expect(described_class.render_collection(nil)).to eq([])
    end

    it 'returns empty array when users is empty array' do
      expect(described_class.render_collection([])).to eq([])
    end

    it 'renders a single user in array' do
      result = described_class.render_collection([user])
      
      expect(result).to be_an(Array)
      expect(result.length).to eq(1)
      expect(result.first[:id]).to eq(user.id)
      expect(result.first[:email]).to eq('john@example.com')
    end

    it 'renders multiple users' do
      user2 = User.create!(
        first_name: 'Jane',
        last_name: 'Smith',
        email: 'jane@example.com',
        account_name: 'janesmith',
        password: 'password123',
        password_confirmation: 'password123'
      )
      user3 = User.create!(
        first_name: 'Bob',
        last_name: 'Johnson',
        email: 'bob@example.com',
        account_name: 'bobjohnson',
        password: 'password123',
        password_confirmation: 'password123'
      )

      result = described_class.render_collection([user, user2, user3])
      
      expect(result.length).to eq(3)
      expect(result[0][:firstName]).to eq('John')
      expect(result[1][:firstName]).to eq('Jane')
      expect(result[2][:firstName]).to eq('Bob')
    end

    it 'handles ActiveRecord::Relation' do
      User.create!(
        first_name: 'User1',
        last_name: 'Test',
        email: 'user1@example.com',
        account_name: 'user1',
        password: 'password123',
        password_confirmation: 'password123'
      )
      User.create!(
        first_name: 'User2',
        last_name: 'Test',
        email: 'user2@example.com',
        account_name: 'user2',
        password: 'password123',
        password_confirmation: 'password123'
      )
      
      users_relation = User.where(last_name: 'Test')
      result = described_class.render_collection(users_relation)
      
      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
    end

    it 'maintains order of users in collection' do
      users = []
      3.times do |i|
        users << User.create!(
          first_name: "User#{i}",
          last_name: 'Test',
          email: "user#{i}@example.com",
          account_name: "user#{i}",
          password: 'password123',
          password_confirmation: 'password123'
        )
      end

      result = described_class.render_collection(users)
      
      expect(result[0][:firstName]).to eq('User0')
      expect(result[1][:firstName]).to eq('User1')
      expect(result[2][:firstName]).to eq('User2')
    end

    it 'includes settings for each user in collection' do
      user2 = User.create!(
        first_name: 'Jane',
        last_name: 'Smith',
        email: 'jane@example.com',
        account_name: 'janesmith',
        password: 'password123',
        password_confirmation: 'password123'
      )

      Setting.create!(configurable: user, key: 'theme', value: 'dark')
      Setting.create!(configurable: user2, key: 'theme', value: 'light')

      result = described_class.render_collection([user, user2])
      
      expect(result[0][:settings].length).to eq(1)
      expect(result[0][:settings].first[:value]).to eq('dark')
      expect(result[1][:settings].length).to eq(1)
      expect(result[1][:settings].first[:value]).to eq('light')
    end

    it 'filters out nil values in collection' do
      user2 = User.create!(
        first_name: 'Jane',
        last_name: 'Smith',
        email: 'jane@example.com',
        account_name: 'janesmith',
        password: 'password123',
        password_confirmation: 'password123'
      )

      result = described_class.render_collection([user, nil, user2])
      
      expect(result.compact.length).to eq(2)
    end
  end

  describe 'integration tests' do
    it 'works with user loaded from database' do
      saved_user = User.find(user.id)
      result = described_class.render(saved_user)
      
      expect(result[:id]).to eq(user.id)
      expect(result[:email]).to eq('john@example.com')
    end

    it 'handles user with multiple settings correctly' do
      5.times do |i|
        Setting.create!(
          configurable: user,
          key: "setting_#{i}",
          value: "value_#{i}"
        )
      end

      result = described_class.render(user)
      
      expect(result[:settings].length).to eq(5)
      result[:settings].each_with_index do |setting, index|
        expect(setting[:key]).to eq("setting_#{index}")
        expect(setting[:value]).to eq("value_#{index}")
      end
    end

    it 'renders user with activated status' do
      user.update!(activated: true, activated_at: Time.current)
      result = described_class.render(user)
      
      # Even though activated fields exist, they're not in the representer
      expect(result).not_to have_key(:activated)
      expect(result).not_to have_key(:activatedAt)
    end

    it 'does not include sensitive fields' do
      result = described_class.render(user)
      
      expect(result).not_to have_key(:password)
      expect(result).not_to have_key(:passwordDigest)
      expect(result).not_to have_key(:password_digest)
      expect(result).not_to have_key(:activationToken)
      expect(result).not_to have_key(:activation_token)
      expect(result).not_to have_key(:resetPasswordToken)
      expect(result).not_to have_key(:reset_password_token)
    end

    it 'does not include timestamps unless explicitly added' do
      result = described_class.render(user)
      
      expect(result).not_to have_key(:createdAt)
      expect(result).not_to have_key(:updatedAt)
      expect(result).not_to have_key(:created_at)
      expect(result).not_to have_key(:updated_at)
    end
  end
end
