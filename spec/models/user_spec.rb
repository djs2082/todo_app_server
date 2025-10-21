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

  describe 'associations' do
    it 'has many tasks' do
      user = described_class.create!(base_attrs)
      expect(user).to respond_to(:tasks)
    end

    it 'has many settings as configurable' do
      user = described_class.create!(base_attrs)
      expect(user).to respond_to(:settings)
    end

    it 'has many events as initiator' do
      user = described_class.create!(base_attrs)
      expect(user).to respond_to(:events)
    end

    it 'destroys dependent tasks when user is destroyed' do
      user = described_class.create!(base_attrs)
      task = Task.create!(user: user, title: 'Test Task', description: 'Test')
      expect { user.destroy }.to change { Task.count }.by(-1)
    end

    it 'destroys dependent settings when user is destroyed' do
      user = described_class.create!(base_attrs)
      Setting.create!(configurable: user, key: 'theme', value: 'dark')
      expect { user.destroy }.to change { Setting.count }.by(-1)
    end
  end

  describe '#generate_reset_password_token!' do
    it 'generates a reset password token' do
      user = described_class.create!(base_attrs)
      user.generate_reset_password_token!
      expect(user.reset_password_token).to be_present
      expect(user.reset_password_token.length).to be >= 32
    end

    it 'sets reset_password_expires_at to 2 hours from now by default' do
      user = described_class.create!(base_attrs)
      freeze_time = Time.current
      allow(Time).to receive(:current).and_return(freeze_time)
      
      user.generate_reset_password_token!
      expect(user.reset_password_expires_at).to be_within(1.second).of(2.hours.from_now)
    end

    it 'accepts custom ttl parameter' do
      user = described_class.create!(base_attrs)
      user.generate_reset_password_token!(ttl: 1.hour)
      expect(user.reset_password_expires_at).to be_within(1.second).of(1.hour.from_now)
    end

    it 'generates unique tokens for multiple calls' do
      user = described_class.create!(base_attrs)
      user.generate_reset_password_token!
      first_token = user.reset_password_token
      
      user.generate_reset_password_token!
      second_token = user.reset_password_token
      
      expect(first_token).not_to eq(second_token)
    end

    it 'saves without running validations' do
      user = described_class.create!(base_attrs)
      # Make record invalid
      user.email = ''
      expect(user).not_to be_valid
      
      # But generate_reset_password_token! should still work
      expect { user.generate_reset_password_token! }.not_to raise_error
      expect(user.reload.reset_password_token).to be_present
    end
  end

  describe '#reset_password_token_valid?' do
    it 'returns true when token is present and not expired' do
      user = described_class.create!(base_attrs)
      user.generate_reset_password_token!
      expect(user.reset_password_token_valid?).to be true
    end

    it 'returns false when token is nil' do
      user = described_class.create!(base_attrs)
      user.reset_password_token = nil
      user.reset_password_expires_at = 2.hours.from_now
      expect(user.reset_password_token_valid?).to be false
    end

    it 'returns false when expiry is nil' do
      user = described_class.create!(base_attrs)
      user.reset_password_token = 'token123'
      user.reset_password_expires_at = nil
      expect(user.reset_password_token_valid?).to be false
    end

    it 'returns false when token is expired' do
      user = described_class.create!(base_attrs)
      user.reset_password_token = 'token123'
      user.reset_password_expires_at = 1.hour.ago
      expect(user.reset_password_token_valid?).to be false
    end

    it 'returns false when token is exactly at expiry time' do
      user = described_class.create!(base_attrs)
      user.reset_password_token = 'token123'
      expiry_time = Time.current
      user.reset_password_expires_at = expiry_time
      
      allow(Time).to receive(:current).and_return(expiry_time + 1.second)
      expect(user.reset_password_token_valid?).to be false
    end
  end

  describe '#publish_forgot_password_event' do
    it 'publishes user_forgot_password event' do
      user = described_class.create!(base_attrs)
      expect(user).to receive(:publish).with(:user_forgot_password, user)
      user.publish_forgot_password_event
    end
  end

  describe '#publish_password_updated_event' do
    it 'publishes user_password_updated event' do
      user = described_class.create!(base_attrs)
      expect(user).to receive(:publish).with(:user_password_updated, user)
      user.publish_password_updated_event
    end
  end

  describe '#user_signed_in' do
    it 'updates last_singin_at timestamp' do
      user = described_class.create!(base_attrs)
      freeze_time = Time.current
      allow(Time).to receive(:current).and_return(freeze_time)
      
      user.user_signed_in
      expect(user.reload.last_singin_at).to be_within(1.second).of(freeze_time)
    end

    it 'publishes user_signed_in event' do
      user = described_class.create!(base_attrs)
      expect(user).to receive(:publish).with(:user_signed_in, user)
      user.user_signed_in
    end

    it 'does not trigger validations when updating timestamp' do
      user = described_class.create!(base_attrs)
      # Make record invalid
      user.update_column(:email, '')
      
      # user_signed_in should still work
      expect { user.user_signed_in }.not_to raise_error
    end
  end

  describe '#user_first_sign_in' do
    it 'publishes user_first_sign_in event' do
      user = described_class.create!(base_attrs)
      expect(user).to receive(:publish).with(:user_first_sign_in, user)
      user.user_first_sign_in
    end
  end

  describe 'signin_count tracking' do
    it 'defaults signin_count to 0 or nil' do
      user = described_class.create!(base_attrs)
      expect(user.signin_count).to be_nil.or eq(0)
    end

    it 'can be incremented' do
      user = described_class.create!(base_attrs)
      user.update!(signin_count: 1)
      expect(user.signin_count).to eq(1)
    end
  end

  describe 'last_singin_at tracking' do
    it 'defaults last_singin_at to nil' do
      user = described_class.create!(base_attrs)
      expect(user.last_singin_at).to be_nil
    end

    it 'can be set to a timestamp' do
      user = described_class.create!(base_attrs)
      timestamp = Time.current
      user.update!(last_singin_at: timestamp)
      expect(user.last_singin_at).to be_within(1.second).of(timestamp)
    end
  end

  describe '#record_successful_sign_in!' do
    it 'increments count, sets last_singin_at, and publishes both events on first sign-in' do
      user = described_class.create!(base_attrs.merge(signin_count: 0))

      freeze_time = Time.current
      allow(Time).to receive(:current).and_return(freeze_time)

      expect(user).to receive(:publish).with(:user_signed_in, user)
      expect(user).to receive(:publish).with(:user_first_sign_in, user)

      user.record_successful_sign_in!

      user.reload
      expect(user.signin_count).to eq(1)
      expect(user.last_singin_at).to be_within(1.second).of(freeze_time)
    end

    it 'on subsequent sign-ins publishes only user_signed_in and updates timestamp' do
      user = described_class.create!(base_attrs.merge(signin_count: 1, last_singin_at: 1.day.ago))

      later = Time.current + 5.seconds
      allow(Time).to receive(:current).and_return(later)

      expect(user).to receive(:publish).with(:user_signed_in, user)
      expect(user).not_to receive(:publish).with(:user_first_sign_in, user)

      user.record_successful_sign_in!

      user.reload
      expect(user.signin_count).to eq(2)
      expect(user.last_singin_at).to be_within(1.second).of(later)
    end
  end

  describe 'signin_count tracking' do
    it 'defaults signin_count to 0 or nil' do
      user = described_class.create!(base_attrs)
      expect(user.signin_count).to be_nil.or eq(0)
    end

    it 'can be incremented' do
      user = described_class.create!(base_attrs)
      user.update!(signin_count: 1)
      expect(user.signin_count).to eq(1)
    end

    it 'increment! changes the count (no events implied)' do
      user = described_class.create!(base_attrs.merge(signin_count: 0))
      expect { user.increment!(:signin_count) }.to change { user.reload.signin_count }.by(1)
    end
  end

  describe 'password functionality' do
    it 'authenticates with correct password' do
      user = described_class.create!(base_attrs)
      expect(user.authenticate('secret123')).to eq(user)
    end

    it 'returns false with incorrect password' do
      user = described_class.create!(base_attrs)
      expect(user.authenticate('wrongpassword')).to be false
    end

    it 'requires password on create' do
      user = described_class.new(base_attrs.except(:password, :password_confirmation))
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it 'requires password_confirmation to match' do
      user = described_class.new(base_attrs.merge(password_confirmation: 'different'))
      expect(user).not_to be_valid
      expect(user.errors[:password_confirmation]).to be_present
    end
  end

  describe 'activation fields' do
    it 'sets activated to false by default' do
      user = described_class.create!(base_attrs)
      expect(user.activated).to be_falsey
    end

    it 'can be activated' do
      user = described_class.create!(base_attrs)
      user.update!(activated: true, activated_at: Time.current)
      expect(user.activated).to be true
      expect(user.activated_at).to be_present
    end

    it 'can check if user is activated' do
      user = described_class.create!(base_attrs)
      expect(user.activated?).to be_falsey
      
      user.update!(activated: true)
      expect(user.activated?).to be true
    end
  end

  describe 'account_name' do
    it 'requires presence at model level' do
      user = described_class.new(base_attrs.except(:account_name))
      expect(user).not_to be_valid
      expect(user.errors[:account_name]).to include("can't be blank")
    end

    it 'allows different account names for different users' do
      described_class.create!(base_attrs)
      user2 = described_class.new(base_attrs.merge(email: 'other@example.com', account_name: 'othername'))
      expect(user2).to be_valid
    end
  end
end
