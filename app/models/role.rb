class Role < ApplicationRecord
  # Constants
  ADMINISTRATOR = 'administrator'.freeze
  MANAGER = 'manager'.freeze
  USER = 'user'.freeze

  VALID_ROLES = [ADMINISTRATOR, MANAGER, USER].freeze

  # Associations
  has_many :account_users, dependent: :restrict_with_error
  has_many :users, through: :account_users
  has_many :user_invitations, dependent: :restrict_with_error

  # Validations
  validates :name, presence: true, uniqueness: true, inclusion: { in: VALID_ROLES }

  # Class methods
  def self.administrator
    find_by(name: ADMINISTRATOR)
  end

  def self.manager
    find_by(name: MANAGER)
  end

  def self.user
    find_by(name: USER)
  end

  # Instance methods
  def administrator?
    name == ADMINISTRATOR
  end

  def manager?
    name == MANAGER
  end

  def user?
    name == USER
  end

  def can_invite_users?
    administrator? || manager?
  end

  def can_invite_managers?
    administrator?
  end
end
