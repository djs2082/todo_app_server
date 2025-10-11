class SessionsController < ApplicationController
  # POST /login
  def create
    user = User.find_by(email: login_params[:email])
    return render_unauthorized(message: I18n.t("errors.user_not_activated")) unless user&.activated?
    if user&.authenticate(login_params[:password])
      token = JsonWebToken.encode(user_id: user.id)
      render_success(message: I18n.t("success.login_success"), data: { token: token, user: user })
    else
      render_unauthorized(message: I18n.t("errors.invalid_email_or_password"))
    end
  end

  def login_params
    params.require(:user).permit(:email, :password)
  end
end
 