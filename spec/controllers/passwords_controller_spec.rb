require 'rails_helper'

RSpec.describe PasswordsController, type: :controller do
  describe 'POST #create (forgot password)' do
    it 'responds success even if email not found (privacy)' do
      expect(UserMailer).not_to receive(:send_template_email)
      post :create, params: { email: 'nope@example.com' }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['message']).to eq(I18n.t('success.forgot_password_email_sent'))
    end

    it 'generates token and sends email when email exists' do
      user = User.create!(first_name: 'Jane', last_name: 'Doe', email: 'jane@example.com', account_name: 'janedoe', password: 'secret123', password_confirmation: 'secret123')
      mail = double('Mail::Message', deliver_later: :queued, deliver_now: :sent)
      expect(UserMailer).to receive(:send_template_email).with(
        'jane@example.com', 'forgot_password', hash_including(:first_name, :reset_url)
      ).and_return(mail)
      post :create, params: { email: 'jane@example.com' }
      expect(response).to have_http_status(:ok)
      user.reload
      expect(user.reset_password_token).to be_present
      expect(user.reset_password_expires_at).to be_present
    end
  end

  describe 'PUT #update (reset password)' do
    let(:user) do
      User.create!(first_name: 'Jane', last_name: 'Doe', email: 'jane2@example.com', account_name: 'janedoe2', password: 'secret123', password_confirmation: 'secret123', activated: true).tap do |u|
        u.generate_reset_password_token!(ttl: 30.minutes)
      end
    end

    it 'fails when token invalid' do
      put :update, params: { token: 'invalid', password: 'newpass123', password_confirmation: 'newpass123' }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['message']).to eq(I18n.t('errors.reset_password_token_invalid_or_expired'))
    end

    it 'fails when token expired' do
      user.update!(reset_password_expires_at: 1.second.ago)
      put :update, params: { token: user.reset_password_token, password: 'newpass123', password_confirmation: 'newpass123' }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['message']).to eq(I18n.t('errors.reset_password_token_invalid_or_expired'))
    end

    it 'fails when password mismatch' do
      put :update, params: { token: user.reset_password_token, password: 'newpass123', password_confirmation: 'nope' }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['message']).to eq(I18n.t('errors.password_confirmation_mismatch'))
    end

    it 'updates password and clears token, sends confirmation' do
      mail = double('Mail::Message', deliver_later: :queued, deliver_now: :sent)
      # Allow any other mail (e.g., activation) and assert that confirmation was sent
      allow(UserMailer).to receive(:send_template_email).and_return(mail)
      put :update, params: { token: user.reset_password_token, password: 'newpass123', password_confirmation: 'newpass123' }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['message']).to eq(I18n.t('success.password_reset_success'))
      user.reload
      expect(user.authenticate('newpass123')).to be_truthy
      expect(user.reset_password_token).to be_nil
      expect(user.reset_password_expires_at).to be_nil
      expect(UserMailer).to have_received(:send_template_email).with('jane2@example.com', 'password_reset_confirmation', hash_including(:first_name))
    end
  end
end
