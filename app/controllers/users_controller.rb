class UsersController < ApplicationController
  # POST /signup
  def signup
    user = User.new(signup_params)
    begin
      if user.save
        render_created(message: "Successfully signed up. A verification email has been sent. Please check your inbox to activate your account.", data: { id: user.id })
      else
        render_failure(message: "User creation failed", errors: user.errors.full_messages)
      end
    rescue ActiveRecord::RecordNotUnique => e
      # Map DB uniqueness error to a friendly validation error
      render_failure(message: "User creation failed", errors: ["mobile or email has already been taken"])
    end
  end

  # GET /users
  def index
    users = User.all  
    render json: users.as_json(only: [:id, :first_name, :last_name, :mobile, :email, :account_name, :created_at])
  end

  private

  def signup_params
    params.permit(:first_name, :last_name, :mobile, :email, :password, :password_confirmation, :account_name)
  end
end  