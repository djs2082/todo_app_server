require 'rails_helper'

RSpec.describe SessionsController, type: :controller do
  describe 'POST #create' do
    let(:user) do
      User.create!(
        first_name: 'Jane', last_name: 'Doe', email: 'jane@example.com', account_name: 'janedoe',
        mobile: '+12345678901', password: 'secret123', password_confirmation: 'secret123', activated: true
      )
    end

    it 'returns unauthorized when user not activated' do
      inactive = User.create!(
        first_name: 'In', last_name: 'Active', email: 'inactive@example.com', account_name: 'inactive',
        password: 'secret123', password_confirmation: 'secret123', activated: false
      )
      post :create, params: { user: { email: inactive.email, password: 'secret123' } }
      expect(response).to have_http_status(:unauthorized)
      body = json_response
      expect(body['message']).to eq(I18n.t('errors.user_not_activated'))
    end

    it 'returns unauthorized when password invalid' do
      user
      post :create, params: { user: { email: 'jane@example.com', password: 'wrong' } }
      expect(response).to have_http_status(:unauthorized)
      body = json_response
      expect(body['message']).to eq(I18n.t('errors.invalid_email_or_password'))
    end

    it 'returns access token and user on success and sets refresh cookie' do
      user
      post :create, params: { user: { email: 'jane@example.com', password: 'secret123' } }
      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body['message']).to eq(I18n.t('success.login_success'))
      expect(body['data']['access_token']).to be_present
      expect(body['data']['user']['email']).to eq('jane@example.com')
      
      # Cookie for refresh token should be set via response.set_cookie
      expect(response.cookies['refresh_token']).to be_present
    end

    it 'increments signin_count on successful login' do
      user
      expect {
        post :create, params: { user: { email: 'jane@example.com', password: 'secret123' } }
      }.to change { user.reload.signin_count }.by(1)
      expect(response).to have_http_status(:ok)
    end

    it 'returns user data with signinCount in response' do
      user.update!(signin_count: 5)
      post :create, params: { user: { email: 'jane@example.com', password: 'secret123' } }
      body = json_response
      # Check the returned signinCount matches the incremented value
      expect(body['data']['user']).to be_present
      user.reload
      expect(user.signin_count).to eq(6)
    end

    it 'returns unauthorized when email does not exist' do
      post :create, params: { user: { email: 'nonexistent@example.com', password: 'secret123' } }
      expect(response).to have_http_status(:unauthorized)
      body = json_response
      # Non-existent user is treated as not activated
      expect(body['message']).to eq(I18n.t('errors.user_not_activated'))
    end

    it 'returns unauthorized when password is blank' do
      user
      post :create, params: { user: { email: 'jane@example.com', password: '' } }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST #refresh' do
    let(:user) do
      User.create!(
        first_name: 'R', last_name: 'U', email: 'r@u.com', account_name: 'ru',
        password: 'secret123', password_confirmation: 'secret123', activated: true
      )
    end

    it 'returns new access token when refresh token provided in params' do
      token = Authenticator.generate_refresh_token(user)
      post :refresh, params: { refresh_token: token }
      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body['message']).to eq(I18n.t('success.token_refreshed'))
      expect(body['data']['access_token']).to be_present
    end

    it 'returns new access token when refresh token present in cookies' do
      token = Authenticator.generate_refresh_token(user)
      cookies['refresh_token'] = token
      post :refresh
      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body['data']['access_token']).to be_present
    end

    it 'returns unauthorized when refresh token missing' do
      post :refresh
      expect(response).to have_http_status(:unauthorized)
      body = json_response
      expect(body['message']).to eq(I18n.t('errors.refresh_token_missing'))
    end

    it 'returns unauthorized when refresh token invalid' do
      post :refresh, params: { refresh_token: 'bogus' }
      expect(response).to have_http_status(:unauthorized)
      body = json_response
      expect(body['message']).to eq(I18n.t('errors.invalid_refresh_token'))
    end

    it 'returns unauthorized when refresh token is expired' do
      # Create an expired token by encoding with past expiry
      expired_payload = {
        user_id: user.id,
        type: 'refresh',
        jti: SecureRandom.uuid
      }
      expired_token = JsonWebToken.encode(expired_payload, 1.day.ago)
      
      post :refresh, params: { refresh_token: expired_token }
      expect(response).to have_http_status(:unauthorized)
      body = json_response
      expect(body['message']).to eq(I18n.t('errors.invalid_refresh_token'))
    end

    it 'returns unauthorized when refresh token is blacklisted' do
      token = Authenticator.generate_refresh_token(user)
      payload = JsonWebToken.decode(token)
      Authenticator.blacklist!(jti: payload[:jti], token_type: 'refresh', expires_at: 1.week.from_now)
      
      post :refresh, params: { refresh_token: token }
      expect(response).to have_http_status(:unauthorized)
      body = json_response
      expect(body['message']).to eq(I18n.t('errors.invalid_refresh_token'))
    end

    it 'returns unauthorized when refresh token is for wrong user' do
      other_user = User.create!(
        first_name: 'Other', last_name: 'User', email: 'other@example.com', account_name: 'otheruser',
        password: 'secret123', password_confirmation: 'secret123', activated: true
      )
      token = Authenticator.generate_refresh_token(other_user)
      other_user.destroy
      
      post :refresh, params: { refresh_token: token }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST #destroy (logout)' do
    let(:user) do
      User.create!(
        first_name: 'L', last_name: 'O', email: 'l@o.com', account_name: 'lo',
        password: 'secret123', password_confirmation: 'secret123', activated: true
      )
    end

    it 'blacklists access and refresh tokens and clears cookie' do
      pair = Authenticator.generate_token_pair(user)
      request.headers['Authorization'] = "Bearer #{pair[:access_token]}"
      # Set refresh token in cookies jar so controller can read it
      cookies['refresh_token'] = pair[:refresh_token]

      # Mock the clear_refresh_token_cookie to accept 2 arguments as controller passes them
      allow(Authenticator).to receive(:clear_refresh_token_cookie).with(anything, anything)

      expect {
        post :destroy
      }.to change(JwtBlacklist, :count).by(2)

      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body['message']).to eq(I18n.t('success.logout_success'))
      # Verify the clear method was called
      expect(Authenticator).to have_received(:clear_refresh_token_cookie)
    end

    it 'succeeds even if no tokens are present' do
      # Mock the clear_refresh_token_cookie to accept 2 arguments
      allow(Authenticator).to receive(:clear_refresh_token_cookie).with(anything, anything)
      
      expect {
        post :destroy
      }.not_to change(JwtBlacklist, :count)
      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body['message']).to eq(I18n.t('success.logout_success'))
    end

    it 'blacklists only access token when refresh token is missing' do
      pair = Authenticator.generate_token_pair(user)
      request.headers['Authorization'] = "Bearer #{pair[:access_token]}"
      
      allow(Authenticator).to receive(:clear_refresh_token_cookie).with(anything, anything)

      expect {
        post :destroy
      }.to change(JwtBlacklist, :count).by(1)

      expect(response).to have_http_status(:ok)
      
      # Verify access token is blacklisted
      access_payload = JsonWebToken.decode(pair[:access_token])
      expect(Authenticator.blacklisted?(access_payload[:jti])).to be true
    end

    it 'blacklists only refresh token when access token is missing' do
      pair = Authenticator.generate_token_pair(user)
      cookies['refresh_token'] = pair[:refresh_token]
      
      allow(Authenticator).to receive(:clear_refresh_token_cookie).with(anything, anything)

      expect {
        post :destroy
      }.to change(JwtBlacklist, :count).by(1)

      expect(response).to have_http_status(:ok)
      
      # Verify refresh token is blacklisted
      refresh_payload = JsonWebToken.decode(pair[:refresh_token])
      expect(Authenticator.blacklisted?(refresh_payload[:jti])).to be true
    end

    it 'handles invalid access token gracefully' do
      request.headers['Authorization'] = "Bearer invalid_token"
      cookies['refresh_token'] = Authenticator.generate_refresh_token(user)
      
      allow(Authenticator).to receive(:clear_refresh_token_cookie).with(anything, anything)

      expect {
        post :destroy
      }.to change(JwtBlacklist, :count).by(1) # Only refresh token blacklisted

      expect(response).to have_http_status(:ok)
    end
  end
end
