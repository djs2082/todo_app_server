class MakeMobileNullableInUsers < ActiveRecord::Migration[7.1]
  def up
    # Convert existing empty-string mobiles to NULL so unique index won't collide on ''
    change_column_null :users, :mobile, true
    execute "UPDATE users SET mobile = NULL WHERE mobile = ''"
  end

  def down
    # Revert: convert NULL back to empty string and disallow NULL
    execute "UPDATE users SET mobile = '' WHERE mobile IS NULL"
    change_column_null :users, :mobile, false
  end
end
