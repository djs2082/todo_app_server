class CreateEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :events do |t|
      t.string :kind, null: false

      # Polymorphic subject (what the event is about)
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false

      # Polymorphic initiator (who/what caused it) - optional
      t.string :initiator_type
      t.bigint :initiator_id

      # Message payload as JSON (hash)
      t.json :message, null: false

      t.timestamps
    end

    add_index :events, :kind
    add_index :events, [:subject_type, :subject_id]
    add_index :events, [:initiator_type, :initiator_id]
    add_index :events, [:kind, :subject_type, :subject_id], name: 'index_events_on_kind_and_subject'
    add_index :events, :created_at
  end
end