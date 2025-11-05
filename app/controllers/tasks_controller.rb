class TasksController < ApplicationController
    before_action :authenticate_request
    before_action :set_task, except: [:index, :create]
    after_action :verify_authorized, except: [:index]
    after_action :verify_policy_scoped, only: [:index]

  def index
    tasks = policy_scope(Task).includes(:task_pauses, :account)
    grouped = TaskRepresenter.render_collection(tasks)
    render_success(data: grouped)
  end


  def show
    authorize @task
    render_success(data: TaskRepresenter.render_show(@task))
  end

  def create
    task = current_user.tasks.build(task_params)
    task.account = current_account

    authorize task

    if task.save
      render_created(message: "Task created", data: { id: task.id, account_id: task.account_id })
    else
      render_failure(message: "Task creation failed", errors: task.errors.full_messages)
    end
  end

  def update
    authorize @task

    if @task.update(task_params)
      render_success(message: "Task updated", data: { id: @task.id })
    else
      render_failure(message: "Task update failed", errors: @task.errors.full_messages)
    end
  end

  def destroy
    authorize @task

    @task.destroy
    render_success(message: "Task deleted")
  end

   def start
    authorize @task, :start?

    if @task.start!
      render_success(message: 'Task started successfully', data: { task: @task })
    else
      render_failure(message: 'Failed to start task')
    end
  end

  def complete
    authorize @task, :complete?

    if @task.complete!
      render_success(message: 'Task completed successfully', data: { task: @task })
    else
      render_failure(message: 'Failed to complete task')
    end
  end

  def pause
    authorize @task, :pause?

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
    authorize @task, :resume?

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
    @task = policy_scope(Task).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_failure(message: "Task not found", status: :not_found)
  end

  def task_params
    permitted = params.require(:task).permit(:title, :description, :priority, :status, :due_date_time)
    permitted
  end

  def pause_params
    params.require(:data).require(:pause).permit(:reason, :comment, :progress)
  end
end
