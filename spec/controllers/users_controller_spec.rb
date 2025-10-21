require 'rails_helper'

RSpec.describe UsersController, type: :controller do
  describe 'GET #index' do
    it 'returns list of users' do
      User.create!(first_name: 'A', last_name: 'B', email: 'a@b.com', account_name: 'ab', password: 'xpass123', password_confirmation: 'xpass123')
      get :index
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to be_an(Array)
      expect(body.first).to include('id', 'first_name', 'email')
    end

    it 'returns empty array when no users exist' do
      User.delete_all
      get :index
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to eq([])
    end

    it 'returns multiple users' do
      User.create!(first_name: 'User', last_name: 'One', email: 'user1@test.com', account_name: 'user1', password: 'pass123', password_confirmation: 'pass123')
      User.create!(first_name: 'User', last_name: 'Two', email: 'user2@test.com', account_name: 'user2', password: 'pass123', password_confirmation: 'pass123')
      get :index
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.length).to be >= 2
    end

    it 'returns users with correct attributes' do
      user = User.create!(first_name: 'Test', last_name: 'User', email: 'test@example.com', account_name: 'testuser', mobile: '+11234567890', password: 'pass123', password_confirmation: 'pass123')
      get :index
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      user_data = body.find { |u| u['id'] == user.id }
      expect(user_data).to include('id', 'first_name', 'last_name', 'email', 'account_name', 'mobile', 'created_at')
      expect(user_data['first_name']).to eq('Test')
      expect(user_data['email']).to eq('test@example.com')
    end
  end

  describe 'GET #show' do
    it 'returns user data with camelCase keys via representer' do
      user = User.create!(first_name: 'Show', last_name: 'User', email: 'show@example.com', account_name: 'showuser', mobile: '+11234567890', password: 'pass123', password_confirmation: 'pass123', activated: true)
      get :show, params: { id: user.id }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['id']).to eq(user.id)
      expect(body['firstName']).to eq('Show')
      expect(body['lastName']).to eq('User')
      expect(body['email']).to eq('show@example.com')
      expect(body['accountName']).to eq('showuser')
      expect(body['mobile']).to eq('+11234567890')
    end

    it 'returns user with settings array' do
      user = User.create!(first_name: 'With', last_name: 'Settings', email: 'settings@example.com', account_name: 'withsettings', password: 'pass123', password_confirmation: 'pass123')
      Setting.create!(configurable: user, key: 'theme', value: 'dark')
      Setting.create!(configurable: user, key: 'language', value: 'en')
      
      get :show, params: { id: user.id }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['settings']).to be_an(Array)
      expect(body['settings'].length).to eq(2)
      expect(body['settings'].first).to include('id', 'key', 'value')
    end

    it 'returns not found when user does not exist' do
      get :show, params: { id: 99999 }
      expect(response).to have_http_status(:not_found)
      body = JSON.parse(response.body)
      expect(body['message']).to match(/User not found/i)
    end

    it 'returns user without settings if none exist' do
      user = User.create!(first_name: 'No', last_name: 'Settings', email: 'nosettings@example.com', account_name: 'nosettings', password: 'pass123', password_confirmation: 'pass123')
      get :show, params: { id: user.id }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['settings']).to eq([])
    end
  end
  describe 'POST #signup' do
    let(:valid_params) do
      {
        first_name: 'John',
        last_name: 'Doe',
        email: 'john.doe@example.com',
        mobile: '+11234567890',
        password: 'password123',
        password_confirmation: 'password123',
        account_name: 'johndoe'
      }
    end

    let(:invalid_params) do
      valid_params.merge(email: 'bad-email', mobile: '123')
    end

    it 'creates a user with valid params' do
      expect {
        post :signup, params: { user: valid_params }
      }.to change(User, :count).by(1)
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['message']).to eq(I18n.t('signup_activation_mail'))
      expect(json['data']['id']).to be_present
    end

    it 'creates user and sets activated to false by default' do
      post :signup, params: { user: valid_params }
      user = User.last
      expect(user.activated).to be false
      expect(user.activation_token).to be_present
    end

    it 'creates user with valid mobile format' do
      params = valid_params.merge(mobile: '+919876543210')
      expect {
        post :signup, params: { user: params }
      }.to change(User, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it 'returns errors with invalid params' do
      expect {
        post :signup, params: { user: invalid_params }
      }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['message']).to start_with('Validation failed:')
      expect(json['errors']).to include('Email is invalid', 'Mobile must start with + and country code')
    end

    it 'returns error for invalid mobile format only' do
      params = valid_params.merge(mobile: '123')
      expect {
        post :signup, params: { user: params }
      }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to include('Mobile must start with + and country code')
    end

    it 'returns error for invalid email format only' do
      params = valid_params.merge(email: 'bad-email')
      expect {
        post :signup, params: { user: params }
      }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to include('Email is invalid')
    end

    it 'passes if mobile is not present' do
      params = valid_params.except(:mobile)
      expect {
        post :signup, params: { user: params }
      }.to change(User, :count).by(1)
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['message']).to eq(I18n.t('signup_activation_mail'))
      expect(json['data']['id']).to be_present
    end

    it 'fails if email is not present' do
      params = valid_params.except(:email)
      expect {
        post :signup, params: { user: params }
      }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to include("Email can't be blank")
    end

    it 'fails if password and password_confirmation mismatch' do
      params = valid_params.merge(password_confirmation: 'wrongpass')
      expect {
        post :signup, params: { user: params }
      }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to include("Password confirmation doesn't match Password")
    end

    it 'returns errors for missing email and invalid mobile' do
      params = valid_params.except(:email).merge(mobile: '123')
      expect {
        post :signup, params: { user: params }
      }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to include("Email can't be blank", 'Mobile must start with + and country code')
    end

    it 'returns errors for invalid email and password mismatch' do
      params = valid_params.merge(email: 'bad-email', password_confirmation: 'wrongpass')
      expect {
        post :signup, params: { user: params }
      }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to include('Email is invalid', "Password confirmation doesn't match Password")
    end

    it 'fails if first_name is missing' do
      params = valid_params.except(:first_name)
      expect {
        post :signup, params: { user: params }
      }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to include("First name can't be blank")
    end

    it 'fails if last_name is missing' do
      params = valid_params.except(:last_name)
      expect {
        post :signup, params: { user: params }
      }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to include("Last name can't be blank")
    end

    it 'fails if account_name is missing' do
      params = valid_params.except(:account_name)
      expect {
        post :signup, params: { user: params }
      }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to include("Account name can't be blank")
    end

    it 'fails if password is missing' do
      params = valid_params.except(:password, :password_confirmation)
      expect {
        post :signup, params: { user: params }
      }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to include("Password can't be blank")
    end

    it 'fails when email is already taken' do
      User.create!(valid_params)
      expect {
        post :signup, params: { user: valid_params.merge(account_name: 'different') }
      }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['message']).to include('Validation failed')
    end

    it 'fails when account_name is already taken' do
      User.create!(valid_params)
      expect {
        post :signup, params: { user: valid_params.merge(email: 'different@example.com') }
      }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['message']).to include('Validation failed')
    end

    it 'handles record not unique exception' do
      User.create!(valid_params)
      # Simulate race condition by stubbing save to trigger RecordNotUnique
      allow_any_instance_of(User).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)
      
      expect {
        post :signup, params: { user: valid_params.merge(email: 'new@example.com', account_name: 'newaccount') }
      }.not_to change(User, :count)
      
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to include(I18n.t('errors.signup_record_not_unique'))
    end

    it 'returns correct error message format' do
      params = valid_params.except(:email)
      post :signup, params: { user: params }
      json = JSON.parse(response.body)
      expect(json).to have_key('message')
      expect(json).to have_key('errors')
      expect(json['errors']).to be_an(Array)
    end

    it 'does not return password in response' do
      post :signup, params: { user: valid_params }
      json = JSON.parse(response.body)
      expect(json['data']).not_to have_key('password')
      expect(json['data']).not_to have_key('password_digest')
    end
  end

  describe 'PUT #activate' do
    it 'activates user with valid token' do
      user = User.create!(first_name: 'Tok', last_name: 'En', email: 'tok@en.com', account_name: 'tokenuser', password: 'secret123', password_confirmation: 'secret123')
      token = user.activation_token
      put :activate, params: { data: { activation_code: token } }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['message']).to eq(I18n.t('success.account_activated'))
      expect(body['data']).to include('activated' => true)
      expect(user.reload.activated).to be true
      expect(user.activation_token).to be_nil
    end

    it 'sets activated_at timestamp when activating user' do
      user = User.create!(first_name: 'Time', last_name: 'Stamp', email: 'timestamp@example.com', account_name: 'timestamp', password: 'secret123', password_confirmation: 'secret123')
      token = user.activation_token
      expect(user.activated_at).to be_nil
      
      put :activate, params: { data: { activation_code: token } }
      expect(response).to have_http_status(:ok)
      user.reload
      expect(user.activated_at).to be_present
      expect(user.activated_at).to be_within(5.seconds).of(Time.current)
    end

    it 'returns activated when user is already activated' do
      user = User.create!(first_name: 'Al', last_name: 'Ready', email: 'already@ex.com', account_name: 'already', password: 'secret123', password_confirmation: 'secret123', activated: true, activated_at: Time.current)
      token = 'any-token'
      user.update_column(:activation_token, token)
      
      put :activate, params: { data: { activation_code: token } }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['message']).to eq(I18n.t('success.account_already_activated'))
      expect(body['data']).to include('already' => true)
    end

    it 'fails when token missing' do
      put :activate, params: { data: { activation_code: '' } }
      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body['message']).to eq(I18n.t('errors.activation_token_missing', data: { activated: false }))
      expect(body['data']).to include('activated' => false)
    end

    it 'fails when token is nil' do
      put :activate, params: { data: { activation_code: nil } }
      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body['message']).to eq(I18n.t('errors.activation_token_missing', data: { activated: false }))
    end

    it 'fails when token invalid' do
      put :activate, params: { data: { activation_code: 'nope' } }
      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body['message']).to eq(I18n.t('errors.activation_token_missing', data: { activated: false }))
    end

    it 'fails when token is only whitespace' do
      put :activate, params: { data: { activation_code: '   ' } }
      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body['message']).to eq(I18n.t('errors.activation_token_missing', data: { activated: false }))
    end

    it 'trims whitespace from activation token' do
      user = User.create!(first_name: 'Space', last_name: 'Trim', email: 'trim@example.com', account_name: 'spacetrim', password: 'secret123', password_confirmation: 'secret123')
      token = user.activation_token
      
      put :activate, params: { data: { activation_code: "  #{token}  " } }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['message']).to eq(I18n.t('success.account_activated'))
      expect(user.reload.activated).to be true
    end

    it 'clears activation_token after successful activation' do
      user = User.create!(first_name: 'Clear', last_name: 'Token', email: 'clear@example.com', account_name: 'cleartoken', password: 'secret123', password_confirmation: 'secret123')
      token = user.activation_token
      expect(token).to be_present
      
      put :activate, params: { data: { activation_code: token } }
      expect(response).to have_http_status(:ok)
      expect(user.reload.activation_token).to be_nil
    end

    it 'handles database errors gracefully' do
      user = User.create!(first_name: 'Error', last_name: 'Test', email: 'error@example.com', account_name: 'errortest', password: 'secret123', password_confirmation: 'secret123')
      token = user.activation_token
      
      # Simulate database error
      allow_any_instance_of(User).to receive(:update!).and_raise(StandardError.new('Database error'))
      
      put :activate, params: { data: { activation_code: token } }
      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body['message']).to eq(I18n.t('errors.activation_failed'))
      expect(body['data']).to include('activated' => false)
    end

    it 'returns correct response structure on success' do
      user = User.create!(first_name: 'Struct', last_name: 'Test', email: 'struct@example.com', account_name: 'struct', password: 'secret123', password_confirmation: 'secret123')
      token = user.activation_token
      
      put :activate, params: { data: { activation_code: token } }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to have_key('message')
      expect(body).to have_key('data')
      expect(body['data']).to be_a(Hash)
    end

    it 'returns correct response structure on failure' do
      put :activate, params: { data: { activation_code: 'invalid' } }
      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body).to have_key('message')
      expect(body).to have_key('data')
    end

    it 'does not activate user with another users token' do
      user1 = User.create!(first_name: 'User', last_name: 'One', email: 'user1@example.com', account_name: 'user1test', password: 'secret123', password_confirmation: 'secret123')
      user2 = User.create!(first_name: 'User', last_name: 'Two', email: 'user2@example.com', account_name: 'user2test', password: 'secret123', password_confirmation: 'secret123')
      token1 = user1.activation_token
      
      put :activate, params: { data: { activation_code: token1 } }
      expect(response).to have_http_status(:ok)
      
      # user2 should still not be activated
      expect(user2.reload.activated).to be false
      expect(user1.reload.activated).to be true
    end
  end
end
