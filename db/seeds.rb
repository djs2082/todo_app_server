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
