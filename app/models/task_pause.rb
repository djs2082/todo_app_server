# app/models/task_pause.rb
class TaskPause < ApplicationRecord
  # Associations
  belongs_to :task
  has_many :task_events, as: :eventable, dependent: :destroy
  has_many :task_snapshots, as: :snapshotable, dependent: :destroy
  
  # Validations
  validates :paused_at, presence: true
  # validates :reason, inclusion: { 
  #   in: %w[break blocker waiting_for_info dependency other],
  #   allow_nil: true 
  # }
  validates :progress_percentage, 
    numericality: { 
      greater_than_or_equal_to: 0, 
      less_than_or_equal_to: 100 
    },
    allow_nil: true
  
  # Scopes
  scope :active, -> { where(resumed_at: nil) }
  scope :completed, -> { where.not(resumed_at: nil) }
  scope :by_reason, ->(reason) { where(reason: reason) }
  scope :recent, -> { order(paused_at: :desc) }
  
  # Callbacks
  after_create :trigger_pause_notifications
  
  # Instance methods
  def active?
    resumed_at.nil?
  end
  
  def pause_duration
    return 0 if resumed_at.nil?
    (resumed_at - paused_at).to_i
  end
  
  def formatted_pause_duration
    return 'Ongoing' if active?
    seconds_to_time_format(pause_duration)
  end
  
  def formatted_work_duration
    seconds_to_time_format(work_duration)
  end
  
  private
  
  def trigger_pause_notifications
    # Hook for notifications, webhooks, etc.
    TaskPauseNotificationJob.perform_later(id) if reason == 'blocker'
  end
  
  def seconds_to_time_format(seconds)
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    format('%02dh %02dm', hours, minutes)
  end
end