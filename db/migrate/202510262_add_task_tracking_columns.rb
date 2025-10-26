class AddTaskTrackingColumns < ActiveRecord::Migration[7.1]
  def change
    add_column :tasks, :total_working_time, :integer, default: 0, null: false
    add_column :tasks, :started_at, :datetime
    add_column :tasks, :last_resumed_at, :datetime
  end
end
