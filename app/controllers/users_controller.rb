class UsersController < ApplicationController
  # POST /signup
  def signup
    user = User.new(signup_params)

    if user.save
      render json: { id: user.id, message: "User created" }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /users
  def index
    users = User.all
    render json: users.as_json(only: [:id, :first_name, :last_name, :mobile, :email, :account_name, :created_at])
  end

  private

  def signup_params
    params.require(:user).permit(:first_name, :last_name, :mobile, :email, :account_name, :password)
  end
end
