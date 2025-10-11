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

    it 'returns token and user on success' do
      user
      post :create, params: { user: { email: 'jane@example.com', password: 'secret123' } }
      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body['message']).to eq(I18n.t('success.login_success'))
      expect(body['data']['token']).to be_present
      expect(body['data']['user']['email']).to eq('jane@example.com')
    end
  end
end
