class CreateAccountUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :account_users do |t|
      t.references :user, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.references :role, null: false, foreign_key: true
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    # Ensure a user can only have one role per account
    add_index :account_users, [:user_id, :account_id], unique: true
  end
end
