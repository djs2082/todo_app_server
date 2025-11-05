class RemoveAccountNameFromUsers < ActiveRecord::Migration[7.1]
  def up
    if column_exists?(:users, :account_name)
      remove_column :users, :account_name, :string
    end
  end

  def down
    unless column_exists?(:users, :account_name)
      add_column :users, :account_name, :string
    end
  end
end
