class AddLastSinginAtToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :last_singin_at, :datetime
    add_index :users, :last_singin_at
  end
end
