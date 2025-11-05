class CreateUserInvitations < ActiveRecord::Migration[7.1]
  def change
    create_table :user_invitations do |t|
      t.string :email, null: false
      t.string :token, null: false
      t.references :account, null: false, foreign_key: true
      t.references :role, null: false, foreign_key: true
      t.references :invited_by, foreign_key: { to_table: :users }
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.string :status, default: 'pending', null: false # pending, accepted, expired, cancelled

      t.timestamps
    end
    add_index :user_invitations, :token, unique: true
    add_index :user_invitations, :email
    add_index :user_invitations, [:email, :account_id, :status]
  end
end
