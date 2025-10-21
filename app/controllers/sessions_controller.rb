class SessionsController < ApplicationController

  def create
    user = User.find_by(email: login_params[:email])
    return render_unauthorized(message: I18n.t("errors.user_not_activated")) unless user&.activated?
    
    if user&.authenticate(login_params[:password])
      # Record full sign-in effects (count, timestamp, events)
      user.record_successful_sign_in!
      tokens = Authenticator.generate_token_pair(user)
      
      Authenticator.set_refresh_token_cookie(response, cookies, tokens[:refresh_token])
      
      user_payload = {
        id: user.id,
        firstName: user.first_name,
        lastName: user.last_name,
        email: user.email,
        accountName: user.account_name,
      }

      render_success(
        message: I18n.t("success.login_success"), 
        data: { user: UserRepresenter.render(user) ,
        access_token: tokens[:access_token]}
      )
    else
      render_unauthorized(message: I18n.t("errors.invalid_email_or_password"))
    end
  end

  def refresh
    refresh_token = params[:refresh_token] || Authenticator.get_refresh_token_from_cookies(cookies)
    
    unless refresh_token
      return render_unauthorized(message: I18n.t("errors.refresh_token_missing"))
    end

    new_access_token = Authenticator.refresh_access_token(refresh_token)
    
    if new_access_token
      render_success(
        message: I18n.t("success.token_refreshed"),
        data: { access_token: new_access_token }
      )
    else
      render_unauthorized(message: I18n.t("errors.invalid_refresh_token"))
    end
  end

  def destroy
    if request.headers['Authorization']
      access = Authenticator.extract_token_from_header(request.headers['Authorization'])
      if (payload = JsonWebToken.decode(access))
        Authenticator.blacklist!(jti: payload[:jti], token_type: 'access', expires_at: Time.at(payload[:exp])) if payload[:jti]
      end
    end

    if (refresh = Authenticator.get_refresh_token_from_cookies(cookies))
      if (payload = JsonWebToken.decode(refresh))
        Authenticator.blacklist!(jti: payload[:jti], token_type: 'refresh', expires_at: Time.at(payload[:exp])) if payload[:jti]
      end
    end

    Authenticator.clear_refresh_token_cookie(response, cookies)
    render_success(message: I18n.t("success.logout_success"))
  end

  private

  def login_params
    params.require(:user).permit(:email, :password)
  end
end
 