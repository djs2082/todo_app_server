class CleanupJob < ApplicationJob
  @queue = :maintenance

  def perform
    # Clean up old logs, temporary files, etc.
    Rails.logger.info "Running scheduled cleanup job"
    
    # Example: Remove old temporary files
    FileUtils.rm_rf(Dir[Rails.root.join('tmp', 'cache', '*')])
    
    # Example: Clean up old records
    OldRecord.where('created_at < ?', 30.days.ago).delete_all
  end
end