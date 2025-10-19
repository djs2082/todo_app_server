class User < ApplicationRecord
  # Validation regex constants
  EMAIL_REGEX  = URI::MailTo::EMAIL_REGEXP
  # Require E.164-like international format starting with + and country code
  # Examples: +18989898989, +919090909090
  MOBILE_REGEX = /\A\+[1-9]\d{9,14}\z/

  include Events::Publisher

  has_secure_password
  has_many :events, as: :initiator
  has_many :tasks, dependent: :destroy

  validates :first_name, :last_name, :email, presence: true
  validates :email, uniqueness: true, format: { with: EMAIL_REGEX, message: 'is invalid' }

  before_validation :normalize_mobile
  before_create :set_activation_fields
  after_commit :publish_user_signed_up_event, on: :create

  validates :mobile, format: { with: MOBILE_REGEX, message: "must start with + and country code" }, allow_nil: true
  validates :mobile, uniqueness: true, allow_nil: true

  def default_event_message
      { title: "User #{first_name} #{last_name} signed up", description: "A new user has created an account with email #{email}", user_id: id }
  end

  def generate_reset_password_token!(ttl: 2.hours)
    self.reset_password_token = SecureRandom.urlsafe_base64(32)
    self.reset_password_expires_at = ttl.from_now
    save!(validate: false)
  end

  def reset_password_token_valid?
    reset_password_token.present? && reset_password_expires_at.present? && Time.current <= reset_password_expires_at
  end

  def publish_forgot_password_event 
    publish(:user_forgot_password, self)
  end

  def publish_password_updated_event
    publish(:user_password_updated, self)
  end

  private

  def normalize_mobile
    self.mobile = nil if mobile.blank?
  end

  def set_activation_fields
    self.activation_token = SecureRandom.urlsafe_base64(32)
  end

  def publish_user_signed_up_event
    publish(:user_signed_up, self)
  end
end
