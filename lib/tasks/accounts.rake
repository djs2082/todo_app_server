namespace :accounts do
  desc "Create a new account with an admin user"
  task :create_with_admin, [:account_name, :admin_email, :admin_first_name, :admin_last_name] => :environment do |t, args|
    # Validate arguments
    unless args[:account_name] && args[:admin_email] && args[:admin_first_name] && args[:admin_last_name]
      puts "Usage: rake accounts:create_with_admin[account_name,admin_email,admin_first_name,admin_last_name]"
      puts "Example: rake accounts:create_with_admin['Acme Corp','admin@acme.com','John','Doe']"
      exit 1
    end

    account_name = args[:account_name]
    admin_email = args[:admin_email]
    admin_first_name = args[:admin_first_name]
    admin_last_name = args[:admin_last_name]

    begin
      ActiveRecord::Base.transaction do
        # Create account
        account = Account.create!(
          name: account_name,
          active: true
        )
        puts "✓ Created account: #{account.name} (ID: #{account.id})"

        # Get administrator role
        admin_role = Role.administrator
        unless admin_role
          puts "✗ Error: Administrator role not found. Please run migrations."
          raise ActiveRecord::Rollback
        end

        # Create invitation for admin
        invitation = UserInvitation.create!(
          email: admin_email,
          account: account,
          role: admin_role,
          invited_by_id: nil # System-generated invitation
        )
        puts "✓ Created invitation for admin: #{admin_email}"

        # Send invitation email
        begin
          UserInvitationMailer.invite_admin(invitation).deliver_now
          puts "✓ Sent invitation email to: #{admin_email}"
        rescue => e
          puts "⚠ Warning: Failed to send email (#{e.message})"
          puts "  Invitation token: #{invitation.token}"
        end

        # Display invitation details
        puts "\n" + "="*60
        puts "ACCOUNT CREATED SUCCESSFULLY"
        puts "="*60
        puts "Account Name: #{account.name}"
        puts "Account Slug: #{account.slug}"
        puts "Admin Email: #{admin_email}"
        puts "Invitation Token: #{invitation.token}"
        puts "Invitation Expires: #{invitation.expires_at}"
        puts "\nSignup URL:"
        puts "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/signup?invitation_token=#{invitation.token}"
        puts "="*60
      end
    rescue ActiveRecord::RecordInvalid => e
      puts "✗ Error creating account: #{e.message}"
      exit 1
    rescue => e
      puts "✗ Unexpected error: #{e.message}"
      puts e.backtrace.first(5)
      exit 1
    end
  end

  desc "List all accounts with their admin users"
  task :list => :environment do
    accounts = Account.includes(:users, :account_users => :role).all

    if accounts.empty?
      puts "No accounts found."
      exit 0
    end

    puts "\n" + "="*80
    puts "ACCOUNTS LIST"
    puts "="*80

    accounts.each do |account|
      puts "\nAccount: #{account.name} (ID: #{account.id})"
      puts "  Slug: #{account.slug}"
      puts "  Active: #{account.active? ? 'Yes' : 'No'}"
      puts "  Created: #{account.created_at.strftime('%Y-%m-%d %H:%M')}"

      admins = account.account_users.administrators.includes(:user)
      managers = account.account_users.managers.includes(:user)
      users = account.account_users.regular_users.includes(:user)

      if admins.any?
        puts "\n  Administrators:"
        admins.each do |au|
          puts "    - #{au.user.first_name} #{au.user.last_name} (#{au.user.email})"
        end
      end

      if managers.any?
        puts "\n  Managers:"
        managers.each do |au|
          puts "    - #{au.user.first_name} #{au.user.last_name} (#{au.user.email})"
        end
      end

      if users.any?
        puts "\n  Users:"
        users.each do |au|
          puts "    - #{au.user.first_name} #{au.user.last_name} (#{au.user.email})"
        end
      end

      puts "  " + "-"*76
    end

    puts "="*80
    puts "Total accounts: #{accounts.count}"
    puts "="*80
  end

  desc "Deactivate an account"
  task :deactivate, [:account_id] => :environment do |t, args|
    unless args[:account_id]
      puts "Usage: rake accounts:deactivate[account_id]"
      exit 1
    end

    account = Account.find_by(id: args[:account_id])
    unless account
      puts "✗ Account not found with ID: #{args[:account_id]}"
      exit 1
    end

    if account.update(active: false)
      puts "✓ Account '#{account.name}' has been deactivated."
    else
      puts "✗ Failed to deactivate account: #{account.errors.full_messages.join(', ')}"
      exit 1
    end
  end

  desc "Activate an account"
  task :activate, [:account_id] => :environment do |t, args|
    unless args[:account_id]
      puts "Usage: rake accounts:activate[account_id]"
      exit 1
    end

    account = Account.find_by(id: args[:account_id])
    unless account
      puts "✗ Account not found with ID: #{args[:account_id]}"
      exit 1
    end

    if account.update(active: true)
      puts "✓ Account '#{account.name}' has been activated."
    else
      puts "✗ Failed to activate account: #{account.errors.full_messages.join(', ')}"
      exit 1
    end
  end
end
