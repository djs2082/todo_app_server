class UsersController < ApplicationController
  before_action :authenticate_request, only: [:index, :show]

  def signup
    invitation_token = params[:invitation_token]

    # Check if there's a valid invitation
    invitation = invitation_token.present? ? UserInvitation.find_valid_invitation(invitation_token) : nil

    # If no invitation but email is invited, reject signup
    if invitation.nil? && invitation_token.present?
      return render_failure(
        message: "Invalid or expired invitation token. Please request a new invitation.",
        status: :unprocessable_entity
      )
    end

    # Check if email has pending invitation but no token provided
    email = params.dig(:user, :email)
    if invitation.nil? && email.present?
      pending_invitation = UserInvitation.active.find_by(email: email)
      if pending_invitation.present?
        return render_failure(
          message: "This email has a pending invitation. Please use the invitation link sent to your email.",
          status: :unprocessable_entity
        )
      end
    end
    user = User.new(signup_params)

    begin
      ActiveRecord::Base.transaction do
        if user.save
          # Assign user to account based on invitation or default to KaryaApp
          # Determine account from invitation, or fall back to KaryaApp default
          target_account = invitation&.account || Account.karyaapp_account

          if invitation.present?
            # User was invited - add to the invitation's account with specified role
            target_account.add_user(user, invitation.role)
            invitation.mark_as_accepted!
          else
            # No invitation - add to default account as regular user
            target_account.add_user(user, Role.user)
          end

          render_created(
            message: I18n.t("signup_activation_mail", default: "Signup successful! Please check your email for activation instructions."),
            data: { id: user.id, account: (invitation&.account || Account.karyaapp_account).name }
          )
        else
          render_failure(
            message: I18n.t("errors.signup_fail", errors: user.errors.full_messages&.first, default: "Signup failed"),
            errors: user.errors.full_messages
          )
        end
      end
    rescue ActiveRecord::RecordNotUnique => e
      render_failure(
        message: I18n.t("errors.signup_fail", default: "Signup failed"),
        errors: [I18n.t("errors.signup_record_not_unique", default: "Email or mobile already exists")]
      )
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