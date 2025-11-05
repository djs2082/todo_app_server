# frozen_string_literal: true

class AccountPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      # Users can only see accounts they belong to
      scope.joins(:account_users).where(account_users: { user_id: user.id, active: true })
    end
  end

  def index?
    true # Users can list their accounts
  end

  def show?
    user_belongs_to_account?
  end

  def create?
    false # Only rake tasks can create accounts
  end

  def update?
    user_is_administrator?
  end

  def destroy?
    user_is_administrator?
  end

  def manage_users?
    user_is_administrator? || user_is_manager?
  end

  def invite_users?
    user_is_administrator? || user_is_manager?
  end

  def invite_managers?
    user_is_administrator?
  end

  private

  def user_belongs_to_account?
    user.belongs_to_account?(record)
  end

  def user_is_administrator?
    user.administrator_in?(record)
  end

  def user_is_manager?
    user.manager_in?(record)
  end
end
