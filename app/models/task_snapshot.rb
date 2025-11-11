# app/models/task_snapshot.rb
class TaskSnapshot < ApplicationRecord
  # Polymorphic association
  belongs_to :task
  belongs_to :snapshotable, polymorphic: true
  belongs_to :account, optional: true
  
  # Validations
  validates :snapshot_type, presence: true
  
  # Scopes
  scope :pauses, -> { where(snapshot_type: 'pause') }
  scope :resumes, -> { where(snapshot_type: 'resume') }
  scope :milestones, -> { where(snapshot_type: 'milestone') }
  scope :chronological, -> { order(created_at: :asc) }
  
  # Instance methods
  def progress_change_since_last
    previous = task.task_snapshots
                   .where('created_at < ?', created_at)
                   .order(created_at: :desc)
                   .first
    
    return progress_at_snapshot if previous.nil?
    progress_at_snapshot - previous.progress_at_snapshot
  end
  
  def time_change_since_last
    previous = task.task_snapshots
                   .where('created_at < ?', created_at)
                   .order(created_at: :desc)
                   .first
    
    return total_time_at_snapshot if previous.nil?
    total_time_at_snapshot - previous.total_time_at_snapshot
  end

  private
  after_initialize do
  self.state_data ||= {}
end
end