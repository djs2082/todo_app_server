class UsersController < ApplicationController
  before_action :authenticate_request, only: [:index, :show]
  before_action :set_invitation, only: [:signup]

  def signup
    # Validate invitation token if provided
    if invalid_invitation_token?
      return render_failure(
        message: I18n.t("errors.invalid_invitation_token", default: "Invalid or expired invitation token. Please request a new invitation."),
        status: :unprocessable_entity
      )
    end

    # Block signup when there's a pending invitation for the email but no valid token
    if pending_invitation_for_email?
      return render_failure(
        message: I18n.t("errors.pending_invitation_exists", default: "This email has a pending invitation. Please use the invitation link sent to your email."),
        status: :unprocessable_entity
      )
    end

    user = build_user

    ActiveRecord::Base.transaction do
      if user.save
        assign_user_to_account(user)
        render_signup_success(user)
      else
        handle_signup_failure(user)
      end
    end
  rescue ActiveRecord::RecordNotUnique
    render_failure(
      message: I18n.t("errors.signup_fail", default: "Signup failed"),
      errors: [I18n.t("errors.signup_record_not_unique", default: "Email or mobile already exists")]
    )
  rescue => e
    handle_unexpected_error(e, action: :signup)
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

  def set_invitation
    invitation_token = params[:invitation_token]
    @invitation = invitation_token.present? ? UserInvitation.find_valid_invitation(invitation_token) : nil
  end

  private

  def build_user
    User.new(signup_params)
  end

  def invitation_token
    params[:invitation_token].to_s.presence
  end

  def invalid_invitation_token?
    invitation_token.present? && @invitation.nil?
  end

  def signup_email
    params.dig(:user, :email)
  end

  def pending_invitation_for_email?
    @invitation.nil? && signup_email.present? && UserInvitation.active.exists?(email: signup_email)
  end

  def target_account
    @invitation&.account || Account.karyaapp_account
  end

  def assign_user_to_account(user)
    if @invitation.present?
      target_account.add_user(user, @invitation.role)
      @invitation.mark_as_accepted!
    else
      target_account.add_user(user, Role.user)
    end
  end

  def render_signup_success(user)
    render_created(
      message: I18n.t("signup_activation_mail", default: "Signup successful! Please check your email for activation instructions."),
      data: { id: user.id, account: target_account.name }
    )
  end

  def handle_signup_failure(user)
    render_failure(
      message: I18n.t("errors.signup_fail", errors: user.errors.full_messages&.first, default: "Signup failed"),
      errors: user.errors.full_messages
    )
  end
end  