class CreateSettings < ActiveRecord::Migration[7.1]
  def change
    create_table :settings do |t|
      t.string :configurable_type, null: false
      t.bigint :configurable_id, null: false
      t.string :key, null: false
      t.json :value
      t.timestamps
    end

    add_index :settings, [:configurable_type, :configurable_id]
    add_index :settings, [:configurable_type, :configurable_id, :key], unique: true, name: 'index_settings_on_resource_and_key'
  end
end
