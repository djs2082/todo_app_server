class SessionsController < ApplicationController
  # POST /login
  def create
    user = User.find_by(email: params.dig(:user, :email))

    if user&.authenticate(params.dig(:user, :password))
      token = JsonWebToken.encode(user_id: user.id)
      render json: { token: token, exp: 24.hours.from_now.iso8601 }, status: :ok
    else
      render json: { error: 'Invalid email or password' }, status: :unauthorized
    end
  end
end
