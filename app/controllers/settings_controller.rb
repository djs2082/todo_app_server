class SettingsController < ApplicationController
  before_action :load_configurable, only: [:index, :create]

  # GET /settings?configurable_type=User&configurable_id=1
  def index
    settings = Setting.where(filter_conditions)
    render json: settings.as_json(only: [:id, :key, :value, :configurable_type, :configurable_id])
  end

  # POST /settings
  # { configurable_type: "User", configurable_id: 1, key: "theme", value: { color: "dark" } }
  def create
    setting = Setting.new(setting_params)
    if setting.save
      render json: { id: setting.id, key: setting.key, value: setting.value }, status: :created
    else
      render json: { errors: setting.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /settings/:id
  def update
    setting = Setting.find(params[:id])
    if setting.update(update_params)
      render json: { id: setting.id, key: setting.key, value: setting.value }
    else
      render json: { errors: setting.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /settings/:id
  def destroy
    setting = Setting.find(params[:id])
    setting.destroy
    head :no_content
  end

  private

  def load_configurable
    return unless params[:configurable_type].present? && params[:configurable_id].present?
    # Could validate existence optionally
  end

  def filter_conditions
    conditions = {}
    if params[:configurable_type].present? && params[:configurable_id].present?
      conditions[:configurable_type] = params[:configurable_type]
      conditions[:configurable_id] = params[:configurable_id]
    end
    conditions
  end

  def setting_params
    params.permit(:configurable_type, :configurable_id, :key, :value)
  end

  def update_params
    params.permit(:key, :value)
  end
end
