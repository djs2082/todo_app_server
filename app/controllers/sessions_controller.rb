class SessionsController < ApplicationController
  # POST /login
  def create
    user = User.find_by(email: login_params[:email])

    if user&.authenticate(login_params[:password])
      token = JsonWebToken.encode(user_id: user.id)
      render json: { token: token, exp: 24.hours.from_now.iso8601 }, status: :ok
    else
      render json: { error: 'Invalid email or password' }, status: :unauthorized
    end
  end

  def login_params
    params.permit(:email, :password)
  end
end
 