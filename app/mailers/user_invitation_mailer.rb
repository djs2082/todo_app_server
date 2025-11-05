class UserInvitationMailer < ApplicationMailer
  default from: ENV.fetch('MAILER_FROM_EMAIL', 'noreply@karyaapp.com')

  def invite_user(invitation)
    @invitation = invitation
    @account = invitation.account
    @role = invitation.role
    @inviter = invitation.inviter
    @signup_url = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/signup?invitation_token=#{invitation.token}"
    @expires_at = invitation.expires_at

    mail(
      to: invitation.email,
      subject: "You've been invited to join #{@account.name} on KaryaApp"
    )
  end

  def invite_admin(invitation)
    @invitation = invitation
    @account = invitation.account
    @signup_url = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/signup?invitation_token=#{invitation.token}"
    @expires_at = invitation.expires_at

    mail(
      to: invitation.email,
      subject: "You've been invited as Administrator for #{@account.name}"
    )
  end
end
