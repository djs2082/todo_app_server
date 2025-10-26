class AddDueDateTimeToTasks < ActiveRecord::Migration[7.1]
  def change
    add_column :tasks, :due_date_time, :datetime unless column_exists?(:tasks, :due_date_time)
    add_index :tasks, :due_date_time unless index_exists?(:tasks, :due_date_time)
  end
end
