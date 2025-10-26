class CreateTaskPauses < ActiveRecord::Migration[7.0]
  def change
    create_table :task_pauses do |t|
      t.references :task, null: false, foreign_key: true
      t.datetime :paused_at, null: false
      t.datetime :resumed_at
      t.integer :work_duration, default: 0
      t.string :reason
      t.text :comment
      t.integer :progress_percentage, default: 0

      t.timestamps
    end
    
    add_index :task_pauses, [:task_id, :paused_at]
    add_index :task_pauses, :reason
  end
end