class UsersController < ApplicationController

  def signup
    user = User.new(signup_params)
    begin
      if user.save
        render_created(message: I18n.t("signup_activation_mail"), data: { id: user.id })
      else
        render_failure(message: I18n.t("errors.signup_fail", errors: user.errors.full_messages&.first), errors: user.errors.full_messages)
      end
    rescue ActiveRecord::RecordNotUnique => e
      render_failure(message: I18n.t("errors.signup_fail"), errors: [I18n.t("errors.signup_record_not_unique")])
    end
  end


  def index
    users = User.all  
    render json: users.as_json(only: [:id, :first_name, :last_name, :mobile, :email, :account_name, :created_at])
  end

  def show
    user = User.find_by(id: params[:id])
    unless user
      return render_failure(message: I18n.t('errors.user_not_found', default: 'User not found'), status: :not_found)
    end
    render json: ::UserRepresenter.render(user)
  end

  def activate
  token = params.dig(:data, :activation_code).to_s.strip
  return render_failure(message: I18n.t("errors.activation_token_missing", data: { activated: false }), data: { activated: false }) if token.blank?

  user = User.find_by(activation_token: token)
  return render_failure(message: I18n.t("errors.activation_token_missing", data: { activated: false }), data: { activated: false }) unless user

    if user.activated?
      return render_success(message: I18n.t("success.account_already_activated"), data: { already: true })
    end

    user.update!(activated: true, activated_at: Time.current, activation_token: nil)
    render_success(message: I18n.t("success.account_activated"), data: { activated: true })
  rescue => e
    Rails.logger.error("[ACTIVATE_ERROR] token=#{token} error=#{e.class} msg=#{e.message}")
    render_failure(message: I18n.t("errors.activation_failed"), data: { activated: false })
  end

  def signup_params
    params.require(:user).permit(:first_name, :last_name, :mobile, :email, :password, :password_confirmation, :account_name)
  end

end  