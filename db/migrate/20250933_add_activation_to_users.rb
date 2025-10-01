class AddActivationToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :activated, :boolean, default: false, null: false
    add_column :users, :activation_token, :string
    add_column :users, :activated_at, :datetime
    add_index :users, :activation_token, unique: true
  end
end