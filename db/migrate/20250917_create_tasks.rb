class CreateTasks < ActiveRecord::Migration[7.1]
  def change
    create_table :tasks do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.integer :priority
      t.date :due_date
      t.time :due_time

      t.timestamps
    end
  end
end
