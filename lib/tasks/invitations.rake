namespace :invitations do
  desc "Invite users in bulk from a CSV file"
  task :bulk_invite, [:csv_file, :account_id, :role_name, :inviter_id] => :environment do |t, args|
    # Validate arguments
    unless args[:csv_file] && args[:account_id] && args[:role_name]
      puts "Usage: rake invitations:bulk_invite[csv_file,account_id,role_name,inviter_id]"
      puts "Example: rake invitations:bulk_invite['users.csv',1,'user',1]"
      puts "\nCSV Format: email,first_name,last_name (header row optional)"
      puts "Available roles: administrator, manager, user"
      exit 1
    end

    csv_file = args[:csv_file]
    account_id = args[:account_id]
    role_name = args[:role_name]
    inviter_id = args[:inviter_id]

    # Validate file exists
    unless File.exist?(csv_file)
      puts "✗ Error: File not found: #{csv_file}"
      exit 1
    end

    # Find account
    account = Account.find_by(id: account_id)
    unless account
      puts "✗ Error: Account not found with ID: #{account_id}"
      exit 1
    end

    # Find role
    role = Role.find_by(name: role_name)
    unless role
      puts "✗ Error: Role '#{role_name}' not found."
      puts "Available roles: administrator, manager, user"
      exit 1
    end

    # Find inviter (optional)
    inviter = nil
    if inviter_id.present?
      inviter = User.find_by(id: inviter_id)
      unless inviter
        puts "⚠ Warning: Inviter not found with ID: #{inviter_id}. Continuing without inviter."
      end
    end

    require 'csv'

    success_count = 0
    error_count = 0
    skipped_count = 0
    errors = []

    puts "\n" + "="*80
    puts "BULK USER INVITATION"
    puts "="*80
    puts "Account: #{account.name}"
    puts "Role: #{role.name.titleize}"
    puts "Inviter: #{inviter ? "#{inviter.first_name} #{inviter.last_name}" : "System"}"
    puts "File: #{csv_file}"
    puts "="*80
    puts "\nProcessing invitations...\n\n"

    CSV.foreach(csv_file, headers: true, header_converters: :symbol) do |row|
      email = row[:email]&.strip
      first_name = row[:first_name]&.strip
      last_name = row[:last_name]&.strip

      # Validate email
      unless email.present? && email.match?(URI::MailTo::EMAIL_REGEXP)
        puts "✗ Skipping invalid email: #{email}"
        skipped_count += 1
        errors << { email: email, error: "Invalid email format" }
        next
      end

      # Check if user already exists in this account
      existing_user = User.find_by(email: email)
      if existing_user && existing_user.belongs_to_account?(account)
        puts "○ Skipping #{email} - already a member of #{account.name}"
        skipped_count += 1
        next
      end

      # Check for existing pending invitation
      existing_invitation = UserInvitation.active.find_by(email: email, account: account)
      if existing_invitation
        puts "○ Skipping #{email} - active invitation already exists"
        skipped_count += 1
        next
      end

      # Create invitation
      begin
        invitation = UserInvitation.create!(
          email: email,
          account: account,
          role: role,
          invited_by: inviter
        )

        # Send email using EmailService
        begin
          template_name = role.administrator? ? 'invite_admin' : 'invite_user'

          EmailService.send_email(
            to: email,
            template_name: template_name,
            context: {
              account_name: account.name,
              role_name: role.name.titleize,
              inviter_name: inviter ? "#{inviter.first_name} #{inviter.last_name}" : "An administrator",
              signup_url: "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/signup?invitation_token=#{invitation.token}",
              expires_at: invitation.expires_at,
              expiry_days: UserInvitation::TOKEN_EXPIRY_DAYS
            },
            subject: EmailTemplate.find_by(name: template_name)&.subject&.gsub('{{account_name}}', account.name),
            async: true
          )
          puts "✓ Invited: #{email}"
          success_count += 1
        rescue => e
          puts "✓ Invitation created for #{email} (email failed: #{e.message})"
          success_count += 1
        end
      rescue => e
        puts "✗ Failed to invite #{email}: #{e.message}"
        error_count += 1
        errors << { email: email, error: e.message }
      end
    end

    puts "\n" + "="*80
    puts "BULK INVITATION SUMMARY"
    puts "="*80
    puts "Successfully invited: #{success_count}"
    puts "Skipped: #{skipped_count}"
    puts "Errors: #{error_count}"
    puts "="*80

    if errors.any?
      puts "\nERRORS:"
      errors.each do |err|
        puts "  #{err[:email]}: #{err[:error]}"
      end
    end
  end

  desc "List pending invitations for an account"
  task :list_pending, [:account_id] => :environment do |t, args|
    unless args[:account_id]
      puts "Usage: rake invitations:list_pending[account_id]"
      exit 1
    end

    account = Account.find_by(id: args[:account_id])
    unless account
      puts "✗ Account not found with ID: #{args[:account_id]}"
      exit 1
    end

    invitations = UserInvitation.pending.where(account: account).includes(:role, :inviter)

    puts "\n" + "="*80
    puts "PENDING INVITATIONS - #{account.name}"
    puts "="*80

    if invitations.empty?
      puts "No pending invitations found."
    else
      invitations.each do |inv|
        status = inv.expired? ? "[EXPIRED]" : "[ACTIVE]"
        inviter_name = inv.inviter ? "#{inv.inviter.first_name} #{inv.inviter.last_name}" : "System"

        puts "\nEmail: #{inv.email}"
        puts "  Role: #{inv.role.name.titleize}"
        puts "  Invited by: #{inviter_name}"
        puts "  Created: #{inv.created_at.strftime('%Y-%m-%d %H:%M')}"
        puts "  Expires: #{inv.expires_at.strftime('%Y-%m-%d %H:%M')} #{status}"
        puts "  Token: #{inv.token}"
      end
      puts "\n" + "="*80
      puts "Total pending invitations: #{invitations.count}"
    end
    puts "="*80
  end

  desc "Cancel an invitation"
  task :cancel, [:invitation_id] => :environment do |t, args|
    unless args[:invitation_id]
      puts "Usage: rake invitations:cancel[invitation_id]"
      exit 1
    end

    invitation = UserInvitation.find_by(id: args[:invitation_id])
    unless invitation
      puts "✗ Invitation not found with ID: #{args[:invitation_id]}"
      exit 1
    end

    if invitation.mark_as_cancelled!
      puts "✓ Invitation for #{invitation.email} has been cancelled."
    else
      puts "✗ Failed to cancel invitation."
      exit 1
    end
  end

  desc "Expire old invitations"
  task :expire_old => :environment do
    expired = UserInvitation.pending.where('expires_at < ?', Time.current)
    count = expired.count

    if count == 0
      puts "No expired invitations found."
      exit 0
    end

    expired.update_all(status: 'expired')
    puts "✓ Marked #{count} invitation(s) as expired."
  end
end
