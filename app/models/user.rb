class User < ApplicationRecord
  has_secure_password

  validates :first_name, :last_name, :mobile, :email, :account_name, presence: true
  validates :email, uniqueness: true
  validates :mobile, uniqueness: true
end
