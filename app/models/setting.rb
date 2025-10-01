class Setting < ApplicationRecord
  belongs_to :configurable, polymorphic: true

  validates :key, presence: true
  validates :key, uniqueness: { scope: [:configurable_type, :configurable_id], message: "already defined for this resource" }
  # value now stored as plain string (TEXT). Any structured data must be manually serialized by caller.
end
