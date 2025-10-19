require 'rails_helper'

RSpec.describe TasksController, type: :controller do
  let(:user) do
    User.create!(
      first_name: 'T', last_name: 'U', email: 't@u.com', account_name: 'tu',
      password: 'secret123', password_confirmation: 'secret123'
    )
  end

  before do
    token = Authenticator.generate_access_token(user)
    request.headers['Authorization'] = "Bearer #{token}"
  end

  describe 'GET #index' do
    it 'returns list of current user tasks' do
      user.tasks.create!(title: 'Task 1')
      get :index
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['data']).to be_an(Array)
      expect(body['data'].first['title']).to eq('Task 1')
    end
  end

  describe 'POST #create' do
    it 'creates a task' do
      expect {
        post :create, params: { task: { title: 'New Task', description: 'Desc' } }
      }.to change(Task, :count).by(1)
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['data']['id']).to be_present
    end

    it 'fails without title' do
      post :create, params: { task: { description: 'Desc' } }
      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body['errors']).to include("Title can't be blank")
    end
  end

  describe 'GET #show' do
    it 'shows a task' do
      task = user.tasks.create!(title: 'A')
      get :show, params: { id: task.id }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['data']['id']).to eq(task.id)
    end
  end

  describe 'PUT #update' do
    it 'updates a task' do
      task = user.tasks.create!(title: 'A')
      put :update, params: { id: task.id, task: { title: 'B' } }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['data']['id']).to eq(task.id)
      expect(task.reload.title).to eq('B')
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes a task' do
      task = user.tasks.create!(title: 'A')
      expect {
        delete :destroy, params: { id: task.id }
      }.to change(Task, :count).by(-1)
      expect(response).to have_http_status(:ok)
    end
  end
end
