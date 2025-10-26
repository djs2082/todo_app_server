class CreateTaskSnapshots < ActiveRecord::Migration[7.0]
  def change
    create_table :task_snapshots do |t|
      t.references :task, null: false, foreign_key: true
      t.references :snapshotable, polymorphic: true, null: false
      t.string :snapshot_type, null: false
      t.json :state_data
      t.integer :progress_at_snapshot
      t.integer :total_time_at_snapshot
      
      t.timestamps
    end
    
    add_index :task_snapshots, [:task_id, :created_at]
  end
end