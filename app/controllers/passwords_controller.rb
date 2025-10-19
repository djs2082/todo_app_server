class PasswordsController < ApplicationController
  # POST /password/forgot { email: "user@example.com" }
  def create
    email = params[:email].to_s.strip.downcase
    user = User.find_by(email: email)

    if user
      user.generate_reset_password_token!
      user.publish_forgot_password_event
    end

    render_success(message: I18n.t('success.forgot_password_email_sent'))
  end

  def update
    token = params[:token].to_s
    password = params[:password].to_s
    password_confirmation = params[:password_confirmation].to_s

    user = User.find_by(reset_password_token: token)
    unless user&.reset_password_token_valid?
      return render_failure(message: I18n.t('errors.reset_password_token_invalid_or_expired'))
    end

    if password.blank? || password != password_confirmation
      return render_failure(message: I18n.t('errors.password_confirmation_mismatch'))
    end

    if user.update(password: password, password_confirmation: password_confirmation, reset_password_token: nil, reset_password_expires_at: nil)
      user.publish_password_updated_event
      render_success(message: I18n.t('success.password_reset_success'))
    else
      render_failure(message: I18n.t('errors.password_reset_failed'), errors: user.errors.full_messages)
    end
  end
end
