class TasksController < ApplicationController
    before_action :authenticate_request
    before_action :set_task, except: [:index, :create]

  def index
    tasks = current_user.tasks.includes(:task_pauses)
    grouped = TaskIndexRepresenter.render_collection(tasks)
    render_success(data: grouped)
  end

  def show
    render_success(data: @task.as_json(only: [:id, :title, :description, :priority, :status, :due_date_time, :user_id]))
  end

  def create
    task = current_user.tasks.build(task_params)
    if task.save
      render_created(message: "Task created", data: { id: task.id })
    else
      render_failure(message: "Task creation failed", errors: task.errors.full_messages)
    end
  end

  def update
    if @task.update(task_params)
      render_success(message: "Task updated", data: { id: @task.id })
    else
      render_failure(message: "Task update failed", errors: @task.errors.full_messages)
    end
  end

  def destroy
    @task.destroy
    render_success(message: "Task deleted")
  end

   def start
    if @task.start!
      render_success(message: 'Task started successfully', data: { task: @task })
    else
      render_failure(message: 'Failed to start task')
    end
  end

  def complete
    if @task.complete!
      render_success(message: 'Task completed successfully', data: { task: @task })
    else
      render_failure(message: 'Failed to complete task')
    end
  end

  def pause

    pause_service = TaskPauseService.new(@task)
    pause = pause_service.pause(
      reason: pause_params[:reason],
      comment: pause_params[:comment],
      progress: pause_params[:progress]
    )
    
    if pause.persisted?
      render_success(message: 'Task paused successfully', data: {
        pause: pause,
        task: @task.reload,
        stats: pause_service.pause_stats
      })
    else
      render_failure(message: pause.errors.full_messages)
    end
  rescue => e
    render_failure(message: e.message)
  end

   def resume
    pause_service = TaskPauseService.new(@task)
    
    if pause_service.resume
      render json: {
        task: @task.reload,
        message: 'Task resumed successfully'
      }
    else
      render_failure(message: 'Failed to resume task')
    end
  rescue => e
    render_failure(message: e.message)
  end


   def pause_history
    @pauses = @task.pause_history
    render json: @pauses, include: [:task_events, :task_snapshots]
  end
  
  def pause_stats
    pause_service = TaskPauseService.new(@task)
    render json: pause_service.pause_stats
  end

  def events
    @events = @task.task_events.timeline
    render json: @events, include: [:eventable]
  end
  
  def snapshots
    @snapshots = @task.task_snapshots.chronological
    render json: @snapshots, include: [:snapshotable]
  end

   def timeline
    # Combined view of all events and snapshots
    events = @task.task_events.timeline.map { |e| e.as_json.merge(type: 'event') }
    snapshots = @task.task_snapshots.chronological.map { |s| s.as_json.merge(type: 'snapshot') }
    
    timeline = (events + snapshots).sort_by { |item| item['created_at'] }.reverse
    
    render json: timeline
  end

  private

  def set_task
    @task = current_user.tasks.find(params[:id])
  end

  def task_params
    permitted = params.require(:task).permit(:title, :description, :priority, :status, :due_date_time)
    permitted
  end

  def pause_params
    params.require(:data).require(:pause).permit(:reason, :comment, :progress)
  end
end
