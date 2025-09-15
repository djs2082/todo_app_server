# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def check
    render json: {
      status: 'healthy',
      database: database_status,
      redis: redis_status,
      timestamp: Time.current.iso8601
    }
  end

  private

  def database_status
    ActiveRecord::Base.connection.active? ? 'connected' : 'disconnected'
  rescue
    'disconnected'
  end

  def redis_status
    Redis.new(url: ENV['REDIS_URL']).ping == 'PONG' ? 'connected' : 'disconnected'
  rescue
    'disconnected'
  end
end