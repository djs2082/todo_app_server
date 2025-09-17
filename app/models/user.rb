class User < ApplicationRecord
  has_secure_password

  validates :first_name, :last_name, :email, presence: true
  validates :email, uniqueness: true

  # Mobile is optional. When provided it must be 10 digits and unique.
  before_validation :normalize_mobile

  validates :mobile, format: { with: /\A\d{10}\z/, message: "must be 10 digits" }, allow_nil: true
  validates :mobile, uniqueness: true, allow_nil: true

  private

  def normalize_mobile
    self.mobile = nil if mobile.blank?
  end
end
