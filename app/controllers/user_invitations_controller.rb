class UserInvitationsController < ApplicationController
  before_action :authenticate_request
  before_action :set_account, only: [:create, :index]
  before_action :set_invitation, only: [:show, :destroy, :resend]

  # GET /accounts/:account_id/invitations
  def index
    authorize UserInvitation
    invitations = policy_scope(UserInvitation).where(account: @account)

    render_success(
      message: "Invitations retrieved successfully",
      data: UserInvitationRepresenter.render_collection(invitations)
    )
  end

  # POST /accounts/:account_id/invitations
  def create

    service = UserInvitations::CreateService.new(
      account: @account,
      current_user: current_user,
      params: invitation_params
    )
    result = service.call

    if result.success?
      render_created(
        message: result.message,
        data: UserInvitationRepresenter.render(result.invitation)
      )
    else
      render_failure(
        message: result.message,
        errors: result.errors,
        status: result.status
      )
    end

    
      # Send invitation email (will be implemented with mailer)
      # UserInvitationMailer.invite_user(invitation).deliver_later rescue nil

  end

  # GET /invitations/:id
  def show
    authorize @invitation

    render_success(
      message: I18n.t("success.invitation_retrieved", default: "Invitation retrieved successfully") ,
      data: UserInvitationRepresenter.render(@invitation)
    )
  end

  # DELETE /invitations/:id
  def destroy
    authorize @invitation

    if @invitation.mark_as_cancelled!
      render_success(message: I18n.t("success.invitation_canceled", default: "Invitation canceled successfully"))
    else
      render_failure(message: I18n.t("fail_to_cancel_invitation", default: "Failed to cancel invitation"))
    end
  end

  # POST /invitations/:id/resend
  def resend
    authorize @invitation, :resend?

    unless @invitation.pending?
      return render_failure(
        message: I18n.t("errors.pending_invitation_resend_error", default: "Can only resend pending invitations"),
        status: :unprocessable_entity
      )
    end

    if @invitation.expired?
      @invitation.extend_expiry!
    end

    # Resend invitation email using EmailService
    template_name = @invitation.role.administrator? ? 'invite_admin' : 'invite_user'

    EmailService.send_email(
      to: @invitation.email,
      template_name: template_name,
      context: {
        account_name: @invitation.account.name,
        role_name: @invitation.role.name.titleize,
        inviter_name: @invitation.inviter ? "#{@invitation.inviter.first_name} #{@invitation.inviter.last_name}" : "An administrator",
        signup_url: "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/signup?invitation_token=#{@invitation.token}",
        expires_at: @invitation.expires_at,
        expiry_days: UserInvitation::TOKEN_EXPIRY_DAYS
      },
      subject: EmailTemplate.find_by(name: template_name)&.subject&.gsub('{{account_name}}', @invitation.account.name),
      async: false  # Send immediately for resend
    )

    render_success(message: I18n.t("success.invitation_resent", default: "Invitation resent successfully"))
  rescue => e
    Rails.logger.error("Failed to resend invitation: #{e.message}")
    render_failure(message: I18n.t("errors.invitation_resend_failed", default: "Failed to resend invitation"))
  end

  private

  def set_account
    @account = Account.active.find_by(id: params[:account_id])
    unless @account
      render_failure(message: I18n.t("errors.account_not_found", default: "Account not found"), status: :not_found)
    end
  end

  def set_invitation
    @invitation = UserInvitation.find_by(id: params[:id])
    unless @invitation
      render_failure(message: I18n.t("errors.invitation_not_found", default: "Invitation not found"), status: :not_found)
    end
  end

  def invitation_params
    params.permit(:email, :role_id)
  end
end
