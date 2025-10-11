require 'rails_helper'

RSpec.describe SettingsController, type: :controller do
  describe 'GET #index' do
    it 'returns settings filtered by configurable when provided' do
      u = User.create!(first_name: 'F', last_name: 'G', email: 'f@g.com', account_name: 'fg', password: 'secret123', password_confirmation: 'secret123')
      s1 = Setting.create!(configurable: u, key: 'theme', value: 'dark')
      get :index, params: { configurable_type: 'User', configurable_id: u.id }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to be_an(Array)
      expect(body.first['key']).to eq('theme')
    end
  end

  describe 'POST #create' do
    it 'creates a setting' do
      u = User.create!(first_name: 'X', last_name: 'Y', email: 'x@y.com', account_name: 'xy', password: 'secret123', password_confirmation: 'secret123')
      expect {
        post :create, params: { configurable_type: 'User', configurable_id: u.id, key: 'lang', value: 'en' }
      }.to change(Setting, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it 'fails on duplicate key for same resource' do
      u = User.create!(first_name: 'D', last_name: 'U', email: 'd@u.com', account_name: 'du', password: 'secret123', password_confirmation: 'secret123')
      Setting.create!(configurable: u, key: 'lang', value: 'en')
      post :create, params: { configurable_type: 'User', configurable_id: u.id, key: 'lang', value: 'fr' }
      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body['errors']).to include('Key already defined for this resource')
    end
  end

  describe 'PATCH #update' do
    it 'updates a setting value' do
      u = User.create!(first_name: 'P', last_name: 'Q', email: 'p@q.com', account_name: 'pq', password: 'secret123', password_confirmation: 'secret123')
      s = Setting.create!(configurable: u, key: 'lang', value: 'en')
      patch :update, params: { id: s.id, key: 'lang', value: 'fr' }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['value']).to eq('fr')
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes a setting' do
      u = User.create!(first_name: 'R', last_name: 'S', email: 'r@s.com', account_name: 'rs', password: 'secret123', password_confirmation: 'secret123')
      s = Setting.create!(configurable: u, key: 'lang', value: 'en')
      expect {
        delete :destroy, params: { id: s.id }
      }.to change(Setting, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end
end
