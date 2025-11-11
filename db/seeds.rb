puts 'Seeding default email templates...'
EmailTemplate.find_or_create_by!(name: 'welcome') do |t|
	t.subject = 'Welcome to Karya App!'
	t.body = <<~HTML
		<h1>Welcome!</h1>
		<p>Your account is ready. If you see this fallback, the view-based template did not render.</p>
	HTML
end

EmailTemplate.find_or_create_by!(name: 'account_activation') do |t|
	t.subject = 'Activate your Karya App account'
	t.body = <<~HTML
		<h1>Activate Account</h1>
		<p>If you are seeing this, the HTML template file was not used.</p>
	HTML
end

EmailTemplate.find_or_create_by!(name: 'forgot_password') do |t|
	t.subject = 'Reset your Karya App password'
	t.body = <<~HTML
		<h1>Reset Password</h1>
		<p>If you are seeing this, the HTML template file was not used.</p>
	HTML
end

EmailTemplate.find_or_create_by!(name: 'password_reset_confirmation') do |t|
	t.subject = 'Your Karya App password has been reset'
	t.body = <<~HTML
		<h1>Password Reset</h1>
		<p>If you are seeing this, the HTML template file was not used.</p>
	HTML
end
puts 'Email templates seeded.'

puts 'Seeding development data...'

if Rails.env.development?
	# Create a demo account
	account = Account.find_or_create_by!(slug: 'demo') do |a|
		a.name = 'Demo Account'
		a.subscription_tier = 'free'
		a.status = 'active'
	end

	# Create users
	owner = User.find_or_create_by!(email: 'owner@demo.local') do |u|
		u.first_name = 'Olivia'
		u.last_name = 'Owner'
		u.password = 'password'
		u.password_confirmation = 'password'
		u.activated = true
		u.default_account_id = account.id
	end

	member = User.find_or_create_by!(email: 'member@demo.local') do |u|
		u.first_name = 'Mark'
		u.last_name = 'Member'
		u.password = 'password'
		u.password_confirmation = 'password'
		u.activated = true
		u.default_account_id = account.id
	end

	# Memberships
	AccountMembership.find_or_create_by!(account: account, user: owner) do |m|
		m.role = 'owner'
		m.status = 'active'
		m.joined_at = Time.current
		m.can_view_analytics = true
		m.can_manage_members = true
	end

	AccountMembership.find_or_create_by!(account: account, user: member) do |m|
		m.role = 'user'
		m.status = 'active'
		m.joined_at = Time.current
	end

	# Tasks
	t1 = Task.create!(
		user: owner, # legacy association for existing code paths
		title: 'Prepare Q4 report',
		description: 'Draft and review the quarterly report',
		priority: 'high',
		status: 'pending',
		due_date_time: 2.days.from_now,
		account_id: account.id
	)

	t2 = Task.create!(
		user: owner,
		title: 'Team sync meeting',
		description: 'Weekly sync',
		priority: 'medium',
		status: 'in_progress',
		due_date_time: 1.day.from_now,
		account_id: account.id,
		started_at: Time.current,
		last_resumed_at: Time.current
	)

	# Assign one task to member
	TaskAssignment.create!(
		task: t1,
		assigned_by: owner,
		assigned_to: member,
		assigned_at: Time.current,
		status: 'pending'
	)

	t1.update!(assigned_to_id: member.id)

	# Automation rule
	AutomationRule.find_or_create_by!(account: account, name: 'Escalate long pauses', created_by: owner) do |r|
		r.trigger_type = 'task_paused'
		r.trigger_conditions = { pause_duration_gt: 7200, status: 'paused' }
		r.actions = [
			{ type: 'send_notification', target: 'manager', template: 'task_paused_long' },
			{ type: 'update_task', field: 'priority', value: 'high' }
		]
	end

	puts 'Development data seeded.'
end
