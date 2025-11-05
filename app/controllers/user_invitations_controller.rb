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

    # Resend invitation email
    UserInvitationMailer.invite_user(@invitation).deliver_later rescue nil

    render_success(message: I18n.t("success.invitation_resent", default: "Invitation resent successfully"))
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
end
