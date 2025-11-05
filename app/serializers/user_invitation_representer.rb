class UserInvitationRepresenter
  class << self
    def render(invitation)
      return nil unless invitation

      {
        id: invitation.id,
        email: invitation.email,
        status: invitation.status,
        expiresAt: invitation.expires_at,
        acceptedAt: (invitation.accepted_at if invitation.respond_to?(:accepted_at)),
        expired: invitation.expired?,
        account: account_details(invitation),
        role: role_details(invitation),
        inviter: inviter_details(invitation)
      }.compact
    end

    def render_collection(invitations)
      Array(invitations).map { |inv| render(inv) }
    end

    private

    def account_details(invitation)
      acc = invitation.account
      return nil unless acc
      { id: acc.id, name: acc.name }
    end

    def role_details(invitation)
      role = invitation.role
      return nil unless role
      { id: role.id, name: role.name }
    end

    def inviter_details(invitation)
      inviter = invitation.inviter
      return nil unless inviter
      # Reuse existing user representer for consistency
      UserRepresenter.render(inviter)
    end
  end
end
