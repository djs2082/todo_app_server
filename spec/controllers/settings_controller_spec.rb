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

    it 'returns all settings when no filter provided' do
      u1 = User.create!(first_name: 'A', last_name: 'B', email: 'a@b.com', account_name: 'ab', password: 'secret123', password_confirmation: 'secret123')
      u2 = User.create!(first_name: 'C', last_name: 'D', email: 'c@d.com', account_name: 'cd', password: 'secret123', password_confirmation: 'secret123')
      Setting.create!(configurable: u1, key: 'theme', value: 'dark')
      Setting.create!(configurable: u2, key: 'lang', value: 'en')
      
      get :index
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to be_an(Array)
      expect(body.length).to be >= 2
    end

    it 'returns empty array when no settings match filter' do
      get :index, params: { configurable_type: 'User', configurable_id: 99999 }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to eq([])
    end

    it 'returns multiple settings for same configurable' do
      u = User.create!(first_name: 'M', last_name: 'N', email: 'm@n.com', account_name: 'mn', password: 'secret123', password_confirmation: 'secret123')
      Setting.create!(configurable: u, key: 'theme', value: 'dark')
      Setting.create!(configurable: u, key: 'lang', value: 'en')
      Setting.create!(configurable: u, key: 'timezone', value: 'UTC')
      
      get :index, params: { configurable_type: 'User', configurable_id: u.id }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.length).to eq(3)
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

    it 'returns created setting with id, key, and value' do
      u = User.create!(first_name: 'K', last_name: 'L', email: 'k@l.com', account_name: 'kl', password: 'secret123', password_confirmation: 'secret123')
      post :create, params: { configurable_type: 'User', configurable_id: u.id, key: 'timezone', value: 'PST' }
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['id']).to be_present
      expect(body['key']).to eq('timezone')
      expect(body['value']).to eq('PST')
    end

    it 'fails when required params are missing' do
      u = User.create!(first_name: 'E', last_name: 'F', email: 'e@f.com', account_name: 'ef', password: 'secret123', password_confirmation: 'secret123')
      post :create, params: { configurable_type: 'User', configurable_id: u.id, key: '' }
      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body['errors']).to be_present
    end

    it 'allows same key for different configurables' do
      u1 = User.create!(first_name: 'G', last_name: 'H', email: 'g@h.com', account_name: 'gh', password: 'secret123', password_confirmation: 'secret123')
      u2 = User.create!(first_name: 'I', last_name: 'J', email: 'i@j.com', account_name: 'ij', password: 'secret123', password_confirmation: 'secret123')
      
      Setting.create!(configurable: u1, key: 'lang', value: 'en')
      
      expect {
        post :create, params: { configurable_type: 'User', configurable_id: u2.id, key: 'lang', value: 'fr' }
      }.to change(Setting, :count).by(1)
      expect(response).to have_http_status(:created)
    end
  end

  describe 'PATCH #update' do
    it 'updates a setting value' do
      u = User.create!(first_name: 'P', last_name: 'Q', email: 'p@q.com', account_name: 'pq', password: 'secret123', password_confirmation: 'secret123')
      s = Setting.create!(configurable: u, key: 'lang', value: 'en')
      patch :update, params: { id: s.id, data: { key: 'lang', value: 'fr' } }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['value']).to eq('fr')
    end

    it 'returns error when update fails' do
      u = User.create!(first_name: 'U', last_name: 'V', email: 'u@v.com', account_name: 'uv', password: 'secret123', password_confirmation: 'secret123')
      s = Setting.create!(configurable: u, key: 'theme', value: 'light')
      # Try to update with invalid data (if validation exists)
      allow_any_instance_of(Setting).to receive(:update).and_return(false)
      allow_any_instance_of(Setting).to receive_message_chain(:errors, :full_messages).and_return(['Update failed'])
      
      patch :update, params: { id: s.id, data: { value: nil } }
      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body['errors']).to include('Update failed')
    end

    it 'returns 404 when setting not found' do
      expect {
        patch :update, params: { id: 99999, data: { value: 'test' } }
      }.to raise_error(ActiveRecord::RecordNotFound)
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

    it 'returns no content with empty body' do
      u = User.create!(first_name: 'T', last_name: 'U', email: 't@u.com', account_name: 'tu', password: 'secret123', password_confirmation: 'secret123')
      s = Setting.create!(configurable: u, key: 'theme', value: 'dark')
      delete :destroy, params: { id: s.id }
      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_blank
    end

    it 'raises error when setting not found' do
      expect {
        delete :destroy, params: { id: 99999 }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
