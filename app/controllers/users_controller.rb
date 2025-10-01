class UsersController < ApplicationController

  def signup
    user = User.new(signup_params)
    begin
      if user.save
        render_created(message: I18n.t("signup_activation_mail"), data: { id: user.id })
      else
        render_failure(message: I18n.t("errors.signup_fail"), errors: user.errors.full_messages)
      end
    rescue ActiveRecord::RecordNotUnique => e
      # Map DB uniqueness error to a friendly validation error
      render_failure(message: I18n.t("errors.signup_fail"), errors: [I18n.t("errors.signup_record_not_unique")])
    end
  end


  def index
    users = User.all  
    render json: users.as_json(only: [:id, :first_name, :last_name, :mobile, :email, :account_name, :created_at])
  end

  private

  def signup_params
    params.permit(:first_name, :last_name, :mobile, :email, :password, :password_confirmation, :account_name)
  end
end  