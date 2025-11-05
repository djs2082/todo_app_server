# frozen_string_literal: true

class TaskPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      # Users can see their own tasks in accounts they belong to
      account_ids = user.account_users.active.pluck(:account_id)
      scope.where(account_id: account_ids)
    end
  end

  def index?
    true
  end

  def show?
    # Can view if: own task OR admin/manager in same account
    own_task? || can_manage_account_tasks?
  end

  def create?
    # Can create if user belongs to the task's account
    user.belongs_to_account?(record.account)
  end

  def update?
    # Can update if: own task OR admin/manager in same account
    own_task? || can_manage_account_tasks?
  end

  def destroy?
    # Can delete if: own task OR admin in same account
    own_task? || user_is_administrator_in_account?
  end

  # Custom actions
  def start?
    update?
  end

  def pause?
    update?
  end

  def resume?
    update?
  end

  def complete?
    update?
  end

  private

  def own_task?
    record.user_id == user.id
  end

  def can_manage_account_tasks?
    user_is_administrator_in_account? || user_is_manager_in_account?
  end

  def user_is_administrator_in_account?
    user.administrator_in?(record.account)
  end

  def user_is_manager_in_account?
    user.manager_in?(record.account)
  end
end
