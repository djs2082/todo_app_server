require 'rails_helper'

RSpec.describe HealthController, type: :controller do
  describe 'GET #check' do
    it 'returns healthy status with timestamp' do
      get :check
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['status']).to eq('healthy')
      expect(body['timestamp']).to be_present
      expect(%w[connected disconnected]).to include(body['database'])
      expect(%w[connected disconnected]).to include(body['redis'])
    end
  end
end
