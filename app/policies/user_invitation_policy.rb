# frozen_string_literal: true

class UserInvitationPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      # Users can see invitations they sent in their accounts
      account_ids = user.account_users.active.pluck(:account_id)
      scope.where(account_id: account_ids)
    end
  end

  def index?
    true
  end

  def show?
    user.belongs_to_account?(record.account)
  end

  def create?
    # Can invite if user is admin or manager in the account
    # Admins can invite anyone, managers can only invite users (not managers)
    return false unless user.belongs_to_account?(record.account)

    role = user.role_in_account(record.account)
    return false unless role

    if record.role.manager? || record.role.administrator?
      role.administrator? # Only admins can invite managers/admins
    else
      role.can_invite_users? # Admins and managers can invite users
    end
  end

  def destroy?
    # Can cancel invitation if: sent by current user OR user is admin in account
    record.invited_by_id == user.id || user.administrator_in?(record.account)
  end

  def resend?
    destroy? # Same permissions as cancel
  end
end
