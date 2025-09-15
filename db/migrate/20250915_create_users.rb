class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :mobile, null: false
      t.string :email, null: false
      t.string :account_name, null: false
      t.string :password_digest, null: false

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :mobile, unique: true
    add_index :users, :account_name
  end
end
