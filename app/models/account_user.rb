class AccountUser < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :account
  belongs_to :role

  # Validations
  validates :user_id, uniqueness: { scope: :account_id, message: "already has a role in this account" }
  validates :user, :account, :role, presence: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :administrators, -> { joins(:role).where(roles: { name: Role::ADMINISTRATOR }) }
  scope :managers, -> { joins(:role).where(roles: { name: Role::MANAGER }) }
  scope :regular_users, -> { joins(:role).where(roles: { name: Role::USER }) }

  # Delegations
  delegate :name, to: :role, prefix: true
  delegate :name, to: :account, prefix: true
  delegate :administrator?, :manager?, :user?, to: :role

  # Instance methods
  def activate!
    update!(active: true)
  end

  def deactivate!
    update!(active: false)
  end
end
