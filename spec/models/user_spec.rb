require 'rails_helper'

RSpec.describe User, type: :model do
  let(:base_attrs) do
    {
      first_name: 'Jane',
      last_name: 'Doe',
      email: 'jane@example.com',
      account_name: 'janedoe',
      password: 'secret123',
      password_confirmation: 'secret123'
    }
  end

  describe 'validations' do
    it 'is valid with required attributes and E.164 mobile' do
      user = described_class.new(base_attrs.merge(mobile: '+11234567890'))
      expect(user).to be_valid
    end

    it 'is valid without mobile (optional)' do
      user = described_class.new(base_attrs)
      expect(user).to be_valid
    end

    it 'normalizes blank mobile to nil before validation' do
      user = described_class.new(base_attrs.merge(mobile: ''))
      expect(user).to be_valid
      expect(user.mobile).to be_nil
    end

    it 'is invalid with non-E.164 mobile' do
      user = described_class.new(base_attrs.merge(mobile: '123'))
      expect(user).not_to be_valid
      expect(user.errors[:mobile]).to include('must start with + and country code')
    end

    it 'is invalid with + followed by 0 (invalid country code)' do
      user = described_class.new(base_attrs.merge(mobile: '+0123456789'))
      expect(user).not_to be_valid
      expect(user.errors[:mobile]).to include('must start with + and country code')
    end

    it 'requires valid email format' do
      user = described_class.new(base_attrs.merge(email: 'bad-email'))
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('is invalid')
    end

    it 'enforces email uniqueness' do
      described_class.create!(base_attrs)
      dup = described_class.new(base_attrs.merge(account_name: 'janedoe2'))
      expect(dup).not_to be_valid
      expect(dup.errors[:email]).to include('has already been taken')
    end

    it 'enforces mobile uniqueness when present' do
      described_class.create!(base_attrs.merge(email: 'first@example.com', account_name: 'first', mobile: '+19998887777'))
      dup = described_class.new(base_attrs.merge(email: 'second@example.com', account_name: 'second', mobile: '+19998887777'))
      expect(dup).not_to be_valid
      expect(dup.errors[:mobile]).to include('has already been taken')
    end

    it 'allows multiple records with nil mobile (DB allows multiple NULLs on unique index)' do
      described_class.create!(base_attrs)
      user2 = described_class.new(base_attrs.merge(email: 'jane2@example.com', account_name: 'janedoe2'))
      expect(user2).to be_valid
    end
  end

  describe 'callbacks' do
    it 'sets activation_token before create' do
      user = described_class.create!(base_attrs)
      expect(user.activation_token).to be_present
    end

    it 'publishes user_signed_up event after commit on create' do
      expect_any_instance_of(described_class).to receive(:publish).with(:user_signed_up, kind_of(described_class))
      described_class.create!(base_attrs.merge(email: 'event@example.com', account_name: 'eventuser'))
    end
  end

  describe '#default_event_message' do
    it 'returns the expected message hash' do
      user = described_class.create!(base_attrs.merge(email: 'msg@example.com', account_name: 'msguser'))
      msg = user.default_event_message
      expect(msg[:title]).to include('User Jane Doe signed up')
      expect(msg[:description]).to include('msg@example.com')
      expect(msg[:user_id]).to eq(user.id)
    end
  end
end
