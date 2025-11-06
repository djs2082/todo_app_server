class UserInvitation < ApplicationRecord
  include Events::Publisher

  # Constants
  TOKEN_EXPIRY_DAYS = 7

  # Associations
  belongs_to :account
  belongs_to :role
  belongs_to :inviter, class_name: 'User', foreign_key: 'invited_by_id', optional: true

  # Validations
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending accepted expired cancelled] }

  # Callbacks
  before_validation :generate_token, on: :create
  before_validation :set_expiry, on: :create

  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :accepted, -> { where(status: 'accepted') }
  scope :expired, -> { where(status: 'expired') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :active, -> { pending.where('expires_at > ?', Time.current) }

  after_create :publish_invitation_created_event

  # Class methods
  def self.find_valid_invitation(token)
    invitation = find_by(token: token, status: 'pending')
    return nil unless invitation

    if invitation.expired?
      invitation.mark_as_expired!
      return nil
    end

    invitation
  end

  # Instance methods
  def expired?
    expires_at < Time.current
  end

  def mark_as_expired!
    update(status: 'expired')
  end

  def mark_as_accepted!
    update(status: 'accepted', accepted_at: Time.current)
  end

  def mark_as_cancelled!
    update(status: 'cancelled')
  end

  def pending?
    status == 'pending'
  end

  def accepted?
    status == 'accepted'
  end

  def extend_expiry!()
    update(expires_at: TOKEN_EXPIRY_DAYS.days.from_now)
  end

  def publish_resend_event
    publish(:user_invitation_resend, self)
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_expiry
    self.expires_at ||= TOKEN_EXPIRY_DAYS.days.from_now
  end

  def publish_invitation_created_event
    publish(:user_invitation_created, self)
  end
end
