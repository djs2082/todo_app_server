class Task < ApplicationRecord
  belongs_to :user
  has_many :task_pauses, dependent: :destroy
  has_many :task_events, dependent: :destroy
  has_many :task_snapshots, dependent: :destroy

  enum priority: { low: 0, medium: 1, high: 2 }
  enum status: { pending: 0, in_progress: 1, paused: 2, completed: 3 }

  validates :title, presence: true
  validates :priority, inclusion: { in: priorities.keys }
  validates :status, inclusion: { in: statuses.keys }
  validates :total_working_time, numericality: { greater_than_or_equal_to: 0 }

  # Set default priority to 'low' if not provided
  before_validation :set_default_priority, on: :create
  before_validation :set_default_status, on: :create

  scope :active, -> { where(status: ['in_progress', 'paused']) }
  scope :paused, -> { where(status: 'paused') }
  scope :in_progress, -> { where(status: 'in_progress') }

  def start!
    return false if in_progress? || completed?
    
    transaction do
      update!(
        status: 'in_progress',
        started_at: Time.current,
        last_resumed_at: Time.current
      )
      
      create_event('started')
    end
  end

  def pause!(reason:, comment: nil, progress: nil)
    return false unless in_progress?
    
    transaction do
      work_duration = calculate_current_session_duration
      
      task_pause = task_pauses.create!(
        paused_at: Time.current,
        work_duration: work_duration,
        reason: reason,
        comment: comment,
        progress_percentage: progress || 0
      )
      
      increment!(:total_working_time, work_duration)
      update!(status: 'paused')
      
      create_event('paused', task_pause)
      create_snapshot('pause', task_pause, progress)
      
      task_pause
    end
  end

  def resume!
    return false unless paused?
    
    transaction do
      current_pause = task_pauses.where(resumed_at: nil).last
      current_pause&.update!(resumed_at: Time.current)
      
      update!(
        status: 'in_progress',
        last_resumed_at: Time.current
      )
      
      create_event('resumed', current_pause)
    end
  end


  def complete!
    return false if completed?
    
    transaction do
      if in_progress?
        work_duration = calculate_current_session_duration
        increment!(:total_working_time, work_duration)
      end

      update!(status: 'completed')
      create_event('completed')
      create_snapshot('milestone', self, 100)
    end
  end

    def current_pause
    task_pauses.where(resumed_at: nil).last
  end
  
  def pause_count
    task_pauses.count
  end
  
  def total_pause_duration
    task_pauses.where.not(resumed_at: nil).sum do |pause|
      (pause.resumed_at - pause.paused_at).to_i
    end
  end
  
  def formatted_working_time
    seconds_to_time_format(total_working_time)
  end
  
  def pause_history
    task_pauses.order(paused_at: :desc)
  end

  private

  def calculate_current_session_duration
    return 0 unless last_resumed_at
    (Time.current - last_resumed_at).to_i
  end
  
  def create_event(event_type, eventable = self)
    task_events.create!(
      event_type: event_type,
      eventable: eventable,
      metadata: build_event_metadata(event_type)
    )
  end
  
  def create_snapshot(snapshot_type, snapshotable, progress)
    task_snapshots.create!(
      snapshot_type: snapshot_type,
      snapshotable: snapshotable,
      progress_at_snapshot: progress,
      total_time_at_snapshot: total_working_time,
      state_data: {
        status: status,
        pause_count: pause_count,
        total_working_time: total_working_time
      }
    )
  end
  
  def build_event_metadata(event_type)
    {
      total_working_time: total_working_time,
      pause_count: pause_count,
      timestamp: Time.current.to_i
    }
  end

   def seconds_to_time_format(seconds)
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    secs = seconds % 60
    
    format('%02d:%02d:%02d', hours, minutes, secs)
  end

  def set_default_priority
    self.priority ||= 'low'
  end

  def set_default_status
    self.status ||= 'pending'
  end
end
