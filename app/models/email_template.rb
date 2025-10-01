class EmailTemplate < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :subject, presence: true

  # Optional fallback body (if corresponding view file not found)
  # Normal rendering prefers app/views/email_templates/<name>.html.erb
end
