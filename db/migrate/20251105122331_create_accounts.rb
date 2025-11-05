class CreateAccounts < ActiveRecord::Migration[7.1]
  def change
    create_table :accounts do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end
    add_index :accounts, :name, unique: true
    add_index :accounts, :slug, unique: true
  end
end
