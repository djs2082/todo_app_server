class CreateRoles < ActiveRecord::Migration[7.1]
  def change
    create_table :roles do |t|
      t.string :name, null: false
      t.string :description

      t.timestamps
    end
    add_index :roles, :name, unique: true

    # Seed default roles
    reversible do |dir|
      dir.up do
        Role.create!([
          { name: 'administrator', description: 'Full account access - can manage managers and users' },
          { name: 'manager', description: 'Can manage users but not other managers' },
          { name: 'user', description: 'Basic access - can manage own tasks' }
        ])
      end
    end
  end
end
