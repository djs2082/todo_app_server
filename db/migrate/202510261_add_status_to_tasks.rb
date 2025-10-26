class AddStatusToTasks < ActiveRecord::Migration[7.1]
  def change
    add_column :tasks, :status, :integer, null: false, default: 0
    add_index :tasks, :status
  end
end
