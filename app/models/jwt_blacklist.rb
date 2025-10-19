class JwtBlacklist < ApplicationRecord
  validates :jti, presence: true, uniqueness: true
  validates :token_type, presence: true, inclusion: { in: %w[access refresh] }
  validates :expires_at, presence: true

  scope :active, -> { where('expires_at > ?', Time.current) }

  def self.purge_expired!
    where('expires_at <= ?', Time.current).delete_all
  end
end
