class TasksController < ApplicationController
    before_action :authenticate_request
    before_action :set_task, only: [:show, :update, :destroy]

  def index
    tasks = current_user.tasks
    render_success(data: tasks.as_json(only: [:id, :title, :description, :priority, :due_date, :due_time]))
  end

  def show
    render_success(data: @task.as_json(only: [:id, :title, :description, :priority, :due_date, :due_time, :user_id]))
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

  private

  def set_task
    @task = current_user.tasks.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:title, :description, :priority, :due_date, :due_time)
  end
end
