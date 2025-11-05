class Account < ApplicationRecord
  # Associations
  has_many :account_users, dependent: :destroy
  has_many :users, through: :account_users
  has_many :tasks, dependent: :destroy
  has_many :user_invitations, dependent: :destroy

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9\-_]+\z/, message: "only allows lowercase letters, numbers, hyphens and underscores" }

  # Callbacks
  before_validation :generate_slug, on: :create

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  # Class methods
  def self.karyaapp_account
    find_or_create_by!(name: 'KaryaApp') do |account|
      account.slug = 'karyaapp'
      account.active = true
    end
  end

  # Instance methods
  def administrators
    users.joins(:account_users).where(account_users: { role: Role.administrator, account_id: id })
  end

  def managers
    users.joins(:account_users).where(account_users: { role: Role.manager, account_id: id })
  end

  def regular_users
    users.joins(:account_users).where(account_users: { role: Role.user, account_id: id })
  end

  def add_user(user, role)
    account_users.create!(user: user, role: role)
  end

  def remove_user(user)
    account_users.find_by(user: user)&.destroy
  end

  def user_role(user)
    account_users.find_by(user: user)&.role
  end

  def user_count
    users.count
  end

  private

  def generate_slug
    self.slug ||= name.to_s.parameterize if name.present?
  end
end
