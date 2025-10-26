class CreateTaskEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :task_events do |t|
      t.references :task, null: false, foreign_key: true
      t.references :eventable, polymorphic: true, null: false
      t.string :event_type, null: false
      t.json :metadata

      
      t.timestamps
    end
    
    add_index :task_events, [:task_id, :created_at]
    add_index :task_events, :event_type
    add_index :task_events, [:eventable_type, :eventable_id]
  end
end