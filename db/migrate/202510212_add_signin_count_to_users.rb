class AddSigninCountToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :signin_count, :integer, null: false, default: 0
  end
end
