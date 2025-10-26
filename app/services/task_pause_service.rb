# app/services/task_pause_service.rb
class TaskPauseService
  def initialize(task)
    @task = task
  end
  
  def pause(reason:, comment: nil, progress: nil)
    validate_pause!
    
    @task.pause!(
      reason: reason,
      comment: comment,
      progress: progress
    )
  end
  
  def resume
    validate_resume!
    @task.resume!
  end
  
  def pause_stats
    {
      total_pauses: @task.pause_count,
      total_pause_duration: @task.total_pause_duration,
      total_working_time: @task.total_working_time,
      average_pause_duration: calculate_average_pause_duration,
      pauses_by_reason: pauses_grouped_by_reason,
      current_pause: @task.current_pause
    }
  end
  
  private
  
  def validate_pause!
    raise "Task must be in progress to pause" unless @task.in_progress?
  end
  
  def validate_resume!
    raise "Task must be paused to resume" unless @task.paused?
  end
  
  def calculate_average_pause_duration
    completed_pauses = @task.task_pauses.completed
    return 0 if completed_pauses.empty?
    
    completed_pauses.sum(&:pause_duration) / completed_pauses.count
  end
  
  def pauses_grouped_by_reason
    @task.task_pauses.group(:reason).count
  end
end