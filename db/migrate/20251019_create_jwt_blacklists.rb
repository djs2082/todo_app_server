class CreateJwtBlacklists < ActiveRecord::Migration[7.1]
  def change
    create_table :jwt_blacklists do |t|
      t.string   :jti, null: false
      t.string   :token_type, null: false # 'access' or 'refresh'
      t.datetime :expires_at, null: false # natural expiry of the token
      t.timestamps
    end
    add_index :jwt_blacklists, :jti, unique: true
    add_index :jwt_blacklists, :expires_at
  end
end
