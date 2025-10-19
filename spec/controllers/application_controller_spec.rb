require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  controller(ApplicationController) do
    before_action :authenticate_request, only: [:secure]

    def index
      render_success(message: 'OK', data: { ping: 'pong' })
    end

    def create
      render_created(message: 'Made', data: { id: 123 })
    end

    def fail_action
      render_failure(message: 'Nope', errors: ['bad'])
    end

    def unauthorized
      render_unauthorized(message: 'Denied')
    end

    def secure
      render_success(message: 'Secured', data: { user_id: current_user&.id })
    end
  end

  before do
    # Define routes for the anonymous controller actions used in specs
    routes.draw do
      get  'index'        => 'anonymous#index'
      post 'create'       => 'anonymous#create'
      get  'fail_action'  => 'anonymous#fail_action'
      get  'unauthorized' => 'anonymous#unauthorized'
      get  'secure'       => 'anonymous#secure'
    end
  end

  describe 'render helpers' do
    it 'render_success returns 200 and payload' do
      get :index
      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body['message']).to eq('OK')
      expect(body['data']).to eq({ 'ping' => 'pong' })
    end

    it 'render_created returns 201 and payload' do
      post :create
      expect(response).to have_http_status(:created)
      body = json_response
      expect(body['message']).to eq('Made')
      expect(body['data']).to eq({ 'id' => 123 })
    end

    it 'render_failure returns 422 by default and errors' do
      get :fail_action
      expect(response).to have_http_status(:unprocessable_entity)
      body = json_response
      expect(body['message']).to eq('Nope')
      expect(body['errors']).to include('bad')
    end

    it 'render_unauthorized returns 401' do
      get :unauthorized
      expect(response).to have_http_status(:unauthorized)
      body = json_response
      expect(body['message']).to eq('Denied')
    end
  end

  describe 'authenticate_request' do
    let(:user) do
      User.create!(
        first_name: 'Jane',
        last_name: 'Doe',
        email: 'jane@example.com',
        account_name: 'janedoe',
        mobile: '+12345678901',
        password: 'secret123',
        password_confirmation: 'secret123'
      )
    end

    it 'denies access when no token' do
      get :secure
      expect(response).to have_http_status(:unauthorized)
      body = json_response
      expect(body['message']).to eq('Not Authorized')
    end

    it 'denies access when token invalid' do
      request.headers['Authorization'] = 'Bearer invalid.token.here'
      get :secure
      expect(response).to have_http_status(:unauthorized)
      body = json_response
      expect(body['message']).to eq('Not Authorized')
    end

    it 'allows access when token valid' do
      token = Authenticator.generate_access_token(user)
      request.headers['Authorization'] = "Bearer #{token}"
      get :secure
      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body['message']).to eq('Secured')
      expect(body['data']).to eq({ 'user_id' => user.id })
    end
  end
end
