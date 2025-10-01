class User < ApplicationRecord
  include Events::Publisher
   puts "[BOOT CHECK] User model loaded at #{Time.now}"

  has_secure_password
  has_many :events, as: :initiator

  validates :first_name, :last_name, :email, presence: true
  validates :email, uniqueness: true

  # Mobile is optional. When provided it must be 10 digits and unique.
  before_validation :normalize_mobile
  before_create :set_activation_fields
  after_commit :publish_user_signed_up_event, on: :create

  # validates :mobile, format: { with: /\A\d{10}\z/, message: "must be 10 digits" }, allow_nil: true
  # validates :mobile, uniqueness: true, allow_nil: true

  def default_event_message
      { title: "User #{first_name} #{last_name} signed up", description: "A new user has created an account with email #{email}", user_id: id }
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
