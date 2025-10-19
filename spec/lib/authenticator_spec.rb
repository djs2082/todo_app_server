require 'rails_helper'

RSpec.describe Authenticator do
  let(:user) do
    User.create!(
      first_name: 'A', last_name: 'B', email: 'a@b.com', account_name: 'ab',
      password: 'secret123', password_confirmation: 'secret123'
    )
  end

  describe '.generate_token_pair and verification' do
    it 'generates access and refresh tokens with jti and verifies them' do
      pair = described_class.generate_token_pair(user)
      expect(pair[:access_token]).to be_present
      expect(pair[:refresh_token]).to be_present

      access_payload = JsonWebToken.decode(pair[:access_token])
      refresh_payload = JsonWebToken.decode(pair[:refresh_token])
      expect(access_payload[:type]).to eq('access')
      expect(refresh_payload[:type]).to eq('refresh')
      expect(access_payload[:jti]).to be_present
      expect(refresh_payload[:jti]).to be_present

      expect(described_class.verify_access_token(pair[:access_token]).id).to eq(user.id)
      expect(described_class.verify_refresh_token(pair[:refresh_token]).id).to eq(user.id)
    end
  end

  describe '.refresh_access_token' do
    it 'mints a new access token from refresh token' do
      refresh = described_class.generate_refresh_token(user)
      new_access = described_class.refresh_access_token(refresh)
      expect(new_access).to be_present
      payload = JsonWebToken.decode(new_access)
      expect(payload[:type]).to eq('access')
      expect(payload[:user_id]).to eq(user.id)
    end
  end

  describe 'blacklist' do
    it 'blacklists tokens and rejects them' do
      access = described_class.generate_access_token(user)
      payload = JsonWebToken.decode(access)
      described_class.blacklist!(jti: payload[:jti], token_type: 'access', expires_at: Time.at(payload[:exp]))
      expect(described_class.verify_access_token(access)).to be_nil
    end
  end

  describe '.authenticate_request' do
    it 'extracts token from header and verifies' do
      token = described_class.generate_access_token(user)
      expect(described_class.authenticate_request("Bearer #{token}").id).to eq(user.id)
      expect(described_class.authenticate_request(nil)).to be_nil
    end
  end
end
