# app/models/task_event.rb
class TaskEvent < ApplicationRecord
  # Polymorphic association
  belongs_to :task
  belongs_to :eventable, polymorphic: true
  
  # Validations
  validates :event_type, presence: true, 
    inclusion: { in: %w[started paused resumed completed] }
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(event_type: type) }
  scope :pauses, -> { where(event_type: 'paused') }
  scope :resumes, -> { where(event_type: 'resumed') }
  
  # Class methods
  def self.timeline
    includes(:eventable).order(created_at: :desc)
  end
  
  # Instance methods
  def event_description
    case event_type
    when 'paused'
      "Task paused - #{eventable.reason}"
    when 'resumed'
      "Task resumed after #{eventable.formatted_pause_duration}"
    when 'started'
      "Task started"
    when 'completed'
      "Task completed"
    end
  end

  private
  after_initialize do
    self.metadata ||= {}
    end
end