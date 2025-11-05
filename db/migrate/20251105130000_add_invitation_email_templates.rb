class AddInvitationEmailTemplates < ActiveRecord::Migration[7.1]
  def up
    # Add email templates for user invitation
    EmailTemplate.find_or_create_by!(name: 'invite_user') do |t|
      t.subject = "You've been invited to join {{account_name}} on KaryaApp"
      t.body = nil # Will use view file
    end

    # Add email template for admin invitation
    EmailTemplate.find_or_create_by!(name: 'invite_admin') do |t|
      t.subject = "Administrator invitation for {{account_name}} on KaryaApp"
      t.body = nil # Will use view file
    end

    puts "✓ Created email templates for invitations"
  end

  def down
    EmailTemplate.where(name: ['invite_user', 'invite_admin']).destroy_all
  end
end
