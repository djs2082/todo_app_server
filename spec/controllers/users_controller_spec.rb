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

    it 'returns activated when user is already activated' do
      user = User.create!(first_name: 'Al', last_name: 'Ready', email: 'already@ex.com', account_name: 'already', password: 'secret123', password_confirmation: 'secret123', activated: true)
      put :activate, params: { data: { activation_code: user.activation_token } }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['message']).to eq(I18n.t('success.account_already_activated'))
    end

    it 'fails when token missing' do
      put :activate, params: { data: { activation_code: '' } }
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
  end
end
