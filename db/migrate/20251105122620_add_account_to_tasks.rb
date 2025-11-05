class AddAccountToTasks < ActiveRecord::Migration[7.1]
  def change
    # First, create the KaryaApp account if it doesn't exist
    reversible do |dir|
      dir.up do
        karya_account = Account.find_or_create_by!(name: 'KaryaApp') do |account|
          account.slug = 'karyaapp'
          account.active = true
        end

        # Add account_id column (nullable first to allow backfill)
        add_reference :tasks, :account, foreign_key: true

        # Backfill existing tasks with KaryaApp account
        execute "UPDATE tasks SET account_id = #{karya_account.id} WHERE account_id IS NULL"

        # Now make it non-nullable
        change_column_null :tasks, :account_id, false
      end

      dir.down do
        remove_reference :tasks, :account
      end
    end
  end
end
