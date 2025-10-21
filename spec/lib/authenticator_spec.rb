require 'rails_helper'

RSpec.describe Authenticator do
  let(:user) do
    User.create!(
      first_name: 'A', last_name: 'B', email: 'a@b.com', account_name: 'ab',
      password: 'secret123', password_confirmation: 'secret123', activated: true
    )
  end

  describe '.access_token_ttl' do
    it 'returns default 900 seconds (15 minutes)' do
      expect(described_class.access_token_ttl).to eq(900.seconds)
    end

    it 'reads from environment variable if set' do
      allow(ENV).to receive(:fetch).with('ACCESS_TOKEN_TTL_SECONDS', '900').and_return('1800')
      expect(described_class.access_token_ttl).to eq(1800.seconds)
    end
  end

  describe '.refresh_token_ttl' do
    it 'returns default 604800 seconds (7 days)' do
      expect(described_class.refresh_token_ttl).to eq(604800.seconds)
    end

    it 'reads from environment variable if set' do
      allow(ENV).to receive(:fetch).with('REFRESH_TOKEN_TTL_SECONDS', '604800').and_return('86400')
      expect(described_class.refresh_token_ttl).to eq(86400.seconds)
    end
  end

  describe '.generate_access_token' do
    it 'generates a valid access token' do
      token = described_class.generate_access_token(user)
      expect(token).to be_present
      expect(token).to be_a(String)
    end

    it 'includes user_id, email, type, and jti in payload' do
      token = described_class.generate_access_token(user)
      payload = JsonWebToken.decode(token)
      
      expect(payload[:user_id]).to eq(user.id)
      expect(payload[:email]).to eq(user.email)
      expect(payload[:type]).to eq('access')
      expect(payload[:jti]).to be_present
      expect(payload[:jti]).to match(/\A[a-f0-9\-]{36}\z/) # UUID format
    end

    it 'sets expiration based on access_token_ttl' do
      token = described_class.generate_access_token(user)
      payload = JsonWebToken.decode(token)
      
      expect(payload[:exp]).to be_present
      expect(Time.at(payload[:exp])).to be_within(5.seconds).of(described_class.access_token_ttl.from_now)
    end

    it 'generates unique jti for each token' do
      token1 = described_class.generate_access_token(user)
      token2 = described_class.generate_access_token(user)
      
      payload1 = JsonWebToken.decode(token1)
      payload2 = JsonWebToken.decode(token2)
      
      expect(payload1[:jti]).not_to eq(payload2[:jti])
    end
  end

  describe '.generate_refresh_token' do
    it 'generates a valid refresh token' do
      token = described_class.generate_refresh_token(user)
      expect(token).to be_present
      expect(token).to be_a(String)
    end

    it 'includes user_id, type, and jti in payload' do
      token = described_class.generate_refresh_token(user)
      payload = JsonWebToken.decode(token)
      
      expect(payload[:user_id]).to eq(user.id)
      expect(payload[:type]).to eq('refresh')
      expect(payload[:jti]).to be_present
    end

    it 'does not include email in refresh token payload' do
      token = described_class.generate_refresh_token(user)
      payload = JsonWebToken.decode(token)
      
      expect(payload[:email]).to be_nil
    end

    it 'sets expiration based on refresh_token_ttl' do
      token = described_class.generate_refresh_token(user)
      payload = JsonWebToken.decode(token)
      
      expect(payload[:exp]).to be_present
      expect(Time.at(payload[:exp])).to be_within(5.seconds).of(described_class.refresh_token_ttl.from_now)
    end

    it 'generates unique jti for each token' do
      token1 = described_class.generate_refresh_token(user)
      token2 = described_class.generate_refresh_token(user)
      
      payload1 = JsonWebToken.decode(token1)
      payload2 = JsonWebToken.decode(token2)
      
      expect(payload1[:jti]).not_to eq(payload2[:jti])
    end
  end

  describe '.generate_token_pair' do
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

    it 'returns a hash with both tokens' do
      pair = described_class.generate_token_pair(user)
      
      expect(pair).to be_a(Hash)
      expect(pair.keys).to contain_exactly(:access_token, :refresh_token)
    end

    it 'generates different jti for access and refresh tokens' do
      pair = described_class.generate_token_pair(user)
      
      access_payload = JsonWebToken.decode(pair[:access_token])
      refresh_payload = JsonWebToken.decode(pair[:refresh_token])
      
      expect(access_payload[:jti]).not_to eq(refresh_payload[:jti])
    end
  end

  describe '.decode_token' do
    it 'decodes a valid token' do
      token = described_class.generate_access_token(user)
      payload = described_class.decode_token(token)
      
      expect(payload).to be_present
      expect(payload[:user_id]).to eq(user.id)
    end

    it 'returns nil for invalid token' do
      expect(described_class.decode_token('invalid.token.here')).to be_nil
    end

    it 'returns nil for expired token' do
      expired_payload = { user_id: user.id, type: 'access' }
      expired_token = JsonWebToken.encode(expired_payload, 1.hour.ago)
      
      expect(described_class.decode_token(expired_token)).to be_nil
    end
  end

  describe '.verify_access_token' do
    it 'verifies valid access token and returns user' do
      token = described_class.generate_access_token(user)
      verified_user = described_class.verify_access_token(token)
      
      expect(verified_user).to eq(user)
    end

    it 'returns nil for invalid token' do
      expect(described_class.verify_access_token('invalid')).to be_nil
    end

    it 'returns nil for refresh token (wrong type)' do
      refresh = described_class.generate_refresh_token(user)
      expect(described_class.verify_access_token(refresh)).to be_nil
    end

    it 'returns nil for blacklisted token' do
      token = described_class.generate_access_token(user)
      payload = JsonWebToken.decode(token)
      described_class.blacklist!(jti: payload[:jti], token_type: 'access', expires_at: Time.at(payload[:exp]))
      
      expect(described_class.verify_access_token(token)).to be_nil
    end

    it 'returns nil when user does not exist' do
      token = described_class.generate_access_token(user)
      user.destroy
      
      expect(described_class.verify_access_token(token)).to be_nil
    end

    it 'returns nil for expired token' do
      expired_payload = { user_id: user.id, type: 'access', jti: SecureRandom.uuid }
      expired_token = JsonWebToken.encode(expired_payload, 1.hour.ago)
      
      expect(described_class.verify_access_token(expired_token)).to be_nil
    end
  end

  describe '.verify_refresh_token' do
    it 'verifies valid refresh token and returns user' do
      token = described_class.generate_refresh_token(user)
      verified_user = described_class.verify_refresh_token(token)
      
      expect(verified_user).to eq(user)
    end

    it 'returns nil for invalid token' do
      expect(described_class.verify_refresh_token('invalid')).to be_nil
    end

    it 'returns nil for access token (wrong type)' do
      access = described_class.generate_access_token(user)
      expect(described_class.verify_refresh_token(access)).to be_nil
    end

    it 'returns nil for blacklisted token' do
      token = described_class.generate_refresh_token(user)
      payload = JsonWebToken.decode(token)
      described_class.blacklist!(jti: payload[:jti], token_type: 'refresh', expires_at: Time.at(payload[:exp]))
      
      expect(described_class.verify_refresh_token(token)).to be_nil
    end

    it 'returns nil when user does not exist' do
      token = described_class.generate_refresh_token(user)
      user.destroy
      
      expect(described_class.verify_refresh_token(token)).to be_nil
    end

    it 'returns nil for expired token' do
      expired_payload = { user_id: user.id, type: 'refresh', jti: SecureRandom.uuid }
      expired_token = JsonWebToken.encode(expired_payload, 1.hour.ago)
      
      expect(described_class.verify_refresh_token(expired_token)).to be_nil
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

    it 'returns nil for invalid refresh token' do
      expect(described_class.refresh_access_token('invalid')).to be_nil
    end

    it 'returns nil for access token' do
      access = described_class.generate_access_token(user)
      expect(described_class.refresh_access_token(access)).to be_nil
    end

    it 'returns nil for blacklisted refresh token' do
      refresh = described_class.generate_refresh_token(user)
      payload = JsonWebToken.decode(refresh)
      described_class.blacklist!(jti: payload[:jti], token_type: 'refresh', expires_at: Time.at(payload[:exp]))
      
      expect(described_class.refresh_access_token(refresh)).to be_nil
    end

    it 'generates new access token with different jti' do
      refresh = described_class.generate_refresh_token(user)
      refresh_payload = JsonWebToken.decode(refresh)
      
      new_access = described_class.refresh_access_token(refresh)
      access_payload = JsonWebToken.decode(new_access)
      
      expect(access_payload[:jti]).not_to eq(refresh_payload[:jti])
    end

    it 'returns nil when user no longer exists' do
      refresh = described_class.generate_refresh_token(user)
      user.destroy
      
      expect(described_class.refresh_access_token(refresh)).to be_nil
    end
  end

  describe '.extract_token_from_header' do
    it 'extracts token from Bearer header' do
      token = 'abc123xyz'
      expect(described_class.extract_token_from_header("Bearer #{token}")).to eq(token)
    end

    it 'returns nil for nil header' do
      expect(described_class.extract_token_from_header(nil)).to be_nil
    end

    it 'returns nil for empty header' do
      expect(described_class.extract_token_from_header('')).to be_nil
    end

    it 'extracts token from header without Bearer prefix' do
      token = 'abc123xyz'
      expect(described_class.extract_token_from_header(token)).to eq(token)
    end

    it 'handles different case Bearer' do
      token = 'abc123xyz'
      expect(described_class.extract_token_from_header("bearer #{token}")).to eq(token)
    end
  end

  describe '.blacklist!' do
    it 'blacklists tokens and rejects them' do
      access = described_class.generate_access_token(user)
      payload = JsonWebToken.decode(access)
      described_class.blacklist!(jti: payload[:jti], token_type: 'access', expires_at: Time.at(payload[:exp]))
      expect(described_class.verify_access_token(access)).to be_nil
    end

    it 'creates a JwtBlacklist record' do
      jti = SecureRandom.uuid
      expires_at = 1.hour.from_now
      
      expect {
        described_class.blacklist!(jti: jti, token_type: 'access', expires_at: expires_at)
      }.to change(JwtBlacklist, :count).by(1)
      
      record = JwtBlacklist.last
      expect(record.jti).to eq(jti)
      expect(record.token_type).to eq('access')
    end

    it 'handles duplicate blacklist attempt' do
      jti = SecureRandom.uuid
      expires_at = 1.hour.from_now
      
      described_class.blacklist!(jti: jti, token_type: 'access', expires_at: expires_at)
      
      # Second attempt with same jti will raise RecordInvalid due to uniqueness validation
      expect {
        described_class.blacklist!(jti: jti, token_type: 'access', expires_at: expires_at)
      }.to raise_error(ActiveRecord::RecordInvalid, /Jti has already been taken/)
    end

    it 'handles both access and refresh token types' do
      jti_access = SecureRandom.uuid
      jti_refresh = SecureRandom.uuid
      expires_at = 1.hour.from_now
      
      described_class.blacklist!(jti: jti_access, token_type: 'access', expires_at: expires_at)
      described_class.blacklist!(jti: jti_refresh, token_type: 'refresh', expires_at: expires_at)
      
      expect(JwtBlacklist.where(token_type: 'access').count).to eq(1)
      expect(JwtBlacklist.where(token_type: 'refresh').count).to eq(1)
    end
  end

  describe '.blacklisted?' do
    it 'returns true for blacklisted jti' do
      jti = SecureRandom.uuid
      described_class.blacklist!(jti: jti, token_type: 'access', expires_at: 1.hour.from_now)
      
      expect(described_class.blacklisted?(jti)).to be true
    end

    it 'returns false for non-blacklisted jti' do
      expect(described_class.blacklisted?(SecureRandom.uuid)).to be false
    end

    it 'returns false for blank jti' do
      expect(described_class.blacklisted?(nil)).to be false
      expect(described_class.blacklisted?('')).to be false
    end

    it 'returns false for expired blacklist entry' do
      jti = SecureRandom.uuid
      JwtBlacklist.create!(jti: jti, token_type: 'access', expires_at: 1.hour.ago)
      
      expect(described_class.blacklisted?(jti)).to be false
    end

    it 'only checks active blacklist entries' do
      active_jti = SecureRandom.uuid
      expired_jti = SecureRandom.uuid
      
      JwtBlacklist.create!(jti: active_jti, token_type: 'access', expires_at: 1.hour.from_now)
      JwtBlacklist.create!(jti: expired_jti, token_type: 'access', expires_at: 1.hour.ago)
      
      expect(described_class.blacklisted?(active_jti)).to be true
      expect(described_class.blacklisted?(expired_jti)).to be false
    end
  end

  describe '.authenticate_request' do
    it 'extracts token from header and verifies' do
      token = described_class.generate_access_token(user)
      expect(described_class.authenticate_request("Bearer #{token}").id).to eq(user.id)
      expect(described_class.authenticate_request(nil)).to be_nil
    end

    it 'returns nil for invalid token' do
      expect(described_class.authenticate_request("Bearer invalid")).to be_nil
    end

    it 'returns nil for nil header' do
      expect(described_class.authenticate_request(nil)).to be_nil
    end

    it 'returns nil for blacklisted token' do
      token = described_class.generate_access_token(user)
      payload = JsonWebToken.decode(token)
      described_class.blacklist!(jti: payload[:jti], token_type: 'access', expires_at: Time.at(payload[:exp]))
      
      expect(described_class.authenticate_request("Bearer #{token}")).to be_nil
    end

    it 'returns nil for refresh token' do
      refresh = described_class.generate_refresh_token(user)
      expect(described_class.authenticate_request("Bearer #{refresh}")).to be_nil
    end

    it 'works without Bearer prefix' do
      token = described_class.generate_access_token(user)
      expect(described_class.authenticate_request(token).id).to eq(user.id)
    end
  end

  describe '.get_refresh_token_from_cookies' do
    it 'retrieves refresh token from cookies hash' do
      cookies = { refresh_token: 'token123' }
      expect(described_class.get_refresh_token_from_cookies(cookies)).to eq('token123')
    end

    it 'returns nil when cookie is not present' do
      cookies = {}
      expect(described_class.get_refresh_token_from_cookies(cookies)).to be_nil
    end

    it 'handles symbol key in cookies' do
      cookies = { refresh_token: 'token123' }
      expect(described_class.get_refresh_token_from_cookies(cookies)).to eq('token123')
    end
  end

  describe 'integration scenarios' do
    it 'handles full authentication flow' do
      # Generate token pair
      pair = described_class.generate_token_pair(user)
      
      # Verify access token works
      expect(described_class.authenticate_request("Bearer #{pair[:access_token]}")).to eq(user)
      
      # Refresh to get new access token
      new_access = described_class.refresh_access_token(pair[:refresh_token])
      expect(new_access).to be_present
      
      # New access token should work
      expect(described_class.authenticate_request("Bearer #{new_access}")).to eq(user)
      
      # Blacklist refresh token
      refresh_payload = JsonWebToken.decode(pair[:refresh_token])
      described_class.blacklist!(jti: refresh_payload[:jti], token_type: 'refresh', expires_at: Time.at(refresh_payload[:exp]))
      
      # Refresh should no longer work
      expect(described_class.refresh_access_token(pair[:refresh_token])).to be_nil
    end

    it 'handles logout scenario with both tokens' do
      pair = described_class.generate_token_pair(user)
      
      # Blacklist both tokens
      access_payload = JsonWebToken.decode(pair[:access_token])
      refresh_payload = JsonWebToken.decode(pair[:refresh_token])
      
      described_class.blacklist!(jti: access_payload[:jti], token_type: 'access', expires_at: Time.at(access_payload[:exp]))
      described_class.blacklist!(jti: refresh_payload[:jti], token_type: 'refresh', expires_at: Time.at(refresh_payload[:exp]))
      
      # Both should be invalid
      expect(described_class.authenticate_request("Bearer #{pair[:access_token]}")).to be_nil
      expect(described_class.refresh_access_token(pair[:refresh_token])).to be_nil
    end

    it 'old access tokens remain valid after refresh' do
      pair = described_class.generate_token_pair(user)
      old_access = pair[:access_token]
      
      # Refresh to get new access token
      new_access = described_class.refresh_access_token(pair[:refresh_token])
      
      # Both old and new access tokens should work
      expect(described_class.authenticate_request("Bearer #{old_access}")).to eq(user)
      expect(described_class.authenticate_request("Bearer #{new_access}")).to eq(user)
    end
  end
end
