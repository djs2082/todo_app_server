# Email Architecture Refactoring - Sprint 2

## Overview
Refactored invitation email system to match the existing standardized email architecture with database-driven templates, reusable partials, and centralized EmailService.

---

## What Was Changed

### 1. Removed Custom Mailer ❌
**Deleted:**
- `/app/mailers/user_invitation_mailer.rb` - Custom invitation mailer
- `/app/views/user_invitation_mailer/` - Custom invitation views

**Reason:** These didn't follow the existing architecture pattern.

### 2. Created Standardized Email Templates ✅

**New Template Views:**
- `/app/views/email_templates/invite_user.html.erb`
- `/app/views/email_templates/invite_admin.html.erb`

**Key Features:**
- Uses `@variables[:key]` pattern (matches existing templates)
- Leverages existing email partials (`_footer`, `_button`, `_greeing`)
- Consistent styling with other system emails
- Responsive design for email clients

### 3. Added Database Records ✅

**Migration:** `20251105130000_add_invitation_email_templates.rb`

**Email Templates Created:**
```ruby
EmailTemplate.create!(
  name: 'invite_user',
  subject: "You've been invited to join {{account_name}} on KaryaApp"
)

EmailTemplate.create!(
  name: 'invite_admin',
  subject: "Administrator invitation for {{account_name}} on KaryaApp"
)
```

**Features:**
- Subject stored in database
- Dynamic `{{account_name}}` replacement
- Body uses view files (not stored in DB)

### 4. Updated Service Layer ✅

**File:** `/app/services/user_invitations/create_service.rb`

**Changes:**
- Added `send_invitation_email` private method
- Uses `EmailService.send_email()` instead of direct mailer
- Passes context hash to template
- Error handling doesn't fail invitation creation

**Code:**
```ruby
def send_invitation_email(invitation)
  template_name = invitation.role.administrator? ? 'invite_admin' : 'invite_user'

  EmailService.send_email(
    to: invitation.email,
    template_name: template_name,
    context: {
      account_name: invitation.account.name,
      role_name: invitation.role.name.titleize,
      inviter_name: invitation.inviter ? "#{invitation.inviter.first_name} #{invitation.inviter.last_name}" : "An administrator",
      signup_url: "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/signup?invitation_token=#{invitation.token}",
      expires_at: invitation.expires_at,
      expiry_days: UserInvitation::TOKEN_EXPIRY_DAYS
    },
    subject: EmailTemplate.find_by(name: template_name)&.subject&.gsub('{{account_name}}', invitation.account.name),
    async: true
  )
rescue => e
  Rails.logger.error("Failed to send invitation email: #{e.message}")
  # Don't fail the invitation creation if email fails
end
```

### 5. Updated Controller ✅

**File:** `/app/controllers/user_invitations_controller.rb`

**Changes:**
- `resend` action now uses `EmailService.send_email()`
- Removed all references to `UserInvitationMailer`
- Same context pattern as service layer
- Synchronous email send for resend (async: false)

### 6. Updated Rake Tasks ✅

**Files:**
- `/lib/tasks/accounts.rake`
- `/lib/tasks/invitations.rake`

**Changes:**
- Replaced `UserInvitationMailer.invite_admin()` calls
- Replaced `UserInvitationMailer.invite_user()` calls
- All now use `EmailService.send_email()`
- Consistent context passing

### 7. Fixed Service Bug ✅

**File:** `/app/services/user_invitations/create_service.rb`

**Issue:** Dynamic constant assignment error
```ruby
# Before (❌ Error)
def call
  Result = Struct.new(...) # Dynamic assignment inside method
end

# After (✅ Fixed)
class CreateService
  Result = Struct.new(...) # Class-level constant
  def call
    # ...
  end
end
```

---

## Email Architecture Pattern (Standardized)

### 1. Database-Driven Templates

**EmailTemplate Model:**
```ruby
EmailTemplate.create!(
  name: 'template_name',      # Unique identifier
  subject: 'Email Subject',   # Subject stored in DB
  body: nil                    # Optional fallback (usually nil)
)
```

### 2. View Files

**Location:** `/app/views/email_templates/{template_name}.html.erb`

**Variable Access:**
```erb
<%= @variables[:account_name] %>
<%= @variables[:user_name] %>
<%= @variables[:signup_url] %>
```

### 3. Reusable Partials

**Location:** `/app/views/email_templates/partials/`

**Available Partials:**
- `_footer.html.erb` - Standard footer with branding
- `_button.html.erb` - CTA button
- `_greeing.html.erb` - Greeting header
- `_hero.html.erb` - Hero image section
- `_highlight.html.erb` - Highlighted text
- `_feature.html.erb` - Feature list
- `_divider.html.erb` - Visual separator
- `_security_note.html.erb` - Security message
- `_need_help.html.erb` - Support section

**Usage:**
```erb
<%= render 'email_templates/partials/button', locals: {
  href: @variables[:url],
  text: 'Click Here'
} %>
```

### 4. EmailService Usage

**Sending Emails:**
```ruby
EmailService.send_email(
  to: user.email,
  template_name: 'invite_user',
  context: {
    account_name: 'Acme Corp',
    role_name: 'Manager',
    signup_url: 'https://app.com/signup?token=abc123',
    expires_at: 7.days.from_now,
    expiry_days: 7
  },
  subject: 'Custom Subject (optional)',  # Override DB subject
  async: true  # true = deliver_later, false = deliver_now
)
```

### 5. Context Variables Pattern

**Naming Convention:**
- Use snake_case: `account_name`, `first_name`, `signup_url`
- Be descriptive: `expires_at` vs `expiry`
- Include formatted versions if needed: `expiry_days` (integer)

**Common Variables:**
```ruby
{
  # User info
  first_name: user.first_name,
  last_name: user.last_name,
  email: user.email,

  # Account info
  account_name: account.name,
  role_name: role.name.titleize,

  # URLs
  signup_url: "#{ENV['FRONTEND_URL']}/signup?token=#{token}",
  dashboard_url: "#{ENV['FRONTEND_URL']}/dashboard",

  # Timing
  expires_at: DateTime,
  expiry_days: Integer,

  # Additional context
  inviter_name: "John Doe",
  company_name: "Acme Corp"
}
```

---

## Benefits of New Architecture

### 1. Consistency ✅
- All emails follow same pattern
- Reusable partials for common elements
- Single source of truth for email styling

### 2. Database-Driven ✅
- Subjects stored in DB (easy to update without deploy)
- Can add email template management UI later
- Version control friendly (views in git, subjects in DB)

### 3. Maintainability ✅
- One `EmailService` to send all emails
- Easy to add new email types
- Centralized error handling

### 4. Flexibility ✅
- Override subject per-email if needed
- Async or sync sending
- Rich context passing

### 5. Testability ✅
- Mock `EmailService.send_email()`
- Test templates separately
- Verify context variables

---

## Migration Guide

### Before (Old Pattern)
```ruby
# Mailer method
class UserInvitationMailer < ApplicationMailer
  def invite_user(invitation)
    @invitation = invitation
    @account = invitation.account
    mail(to: invitation.email, subject: "You've been invited...")
  end
end

# Sending
UserInvitationMailer.invite_user(invitation).deliver_later

# View
<%= @invitation.account.name %>
```

### After (New Pattern)
```ruby
# No custom mailer needed!

# Sending
EmailService.send_email(
  to: invitation.email,
  template_name: 'invite_user',
  context: {
    account_name: invitation.account.name,
    # ... other variables
  }
)

# View
<%= @variables[:account_name] %>
```

---

## Adding New Email Templates

### Step 1: Create Database Record
```ruby
# In migration or seeds.rb
EmailTemplate.create!(
  name: 'new_template',
  subject: 'Your Subject with {{placeholders}}'
)
```

### Step 2: Create View File
```bash
# File: app/views/email_templates/new_template.html.erb
```

```erb
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <title><%= @variables[:title] %></title>
  </head>
  <body>
    <%= render 'email_templates/partials/greeing', locals: {
      message: "Hi #{@variables[:first_name]},"
    } %>

    <div class="content">
      <p><%= @variables[:message] %></p>

      <%= render 'email_templates/partials/button', locals: {
        href: @variables[:action_url],
        text: 'Take Action'
      } %>
    </div>

    <%= render 'email_templates/partials/footer' %>
  </body>
</html>
```

### Step 3: Send Email
```ruby
EmailService.send_email(
  to: user.email,
  template_name: 'new_template',
  context: {
    first_name: user.first_name,
    title: 'Important Message',
    message: 'Your message here',
    action_url: 'https://app.com/action'
  }
)
```

---

## Testing the Changes

### 1. Test Email Sending
```ruby
# Rails console
invitation = UserInvitation.last

EmailService.send_email(
  to: 'test@example.com',
  template_name: 'invite_user',
  context: {
    account_name: invitation.account.name,
    role_name: invitation.role.name.titleize,
    inviter_name: 'Test User',
    signup_url: "http://localhost:3000/signup?invitation_token=#{invitation.token}",
    expires_at: invitation.expires_at,
    expiry_days: 7
  },
  async: false
)
```

### 2. Test Invitation Creation
```bash
curl -X POST http://localhost:3000/accounts/1/invitations \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "newuser@example.com",
    "role_id": 3
  }'
```

### 3. Test Rake Tasks
```bash
# Create account with admin
rake accounts:create_with_admin['Test Corp','admin@test.com','John','Doe']

# Bulk invite
rake invitations:bulk_invite['users.csv',1,'user',1]
```

### 4. Check Email Templates in DB
```ruby
# Rails console
EmailTemplate.where(name: ['invite_user', 'invite_admin']).each do |t|
  puts "Name: #{t.name}"
  puts "Subject: #{t.subject}"
  puts "-" * 50
end
```

---

## Environment Variables

Ensure these are set in `.env`:

```bash
# Email sender
EMAIL_FROM=support@mail.karya-app.com

# Frontend URL for invitation links
FRONTEND_URL=http://localhost:3000
```

---

## Files Changed Summary

### Removed (3 files)
- ❌ `app/mailers/user_invitation_mailer.rb`
- ❌ `app/views/user_invitation_mailer/invite_user.html.erb`
- ❌ `app/views/user_invitation_mailer/invite_admin.html.erb`

### Added (3 files)
- ✅ `app/views/email_templates/invite_user.html.erb`
- ✅ `app/views/email_templates/invite_admin.html.erb`
- ✅ `db/migrate/20251105130000_add_invitation_email_templates.rb`

### Modified (3 files)
- ✏️ `app/services/user_invitations/create_service.rb`
- ✏️ `app/controllers/user_invitations_controller.rb`
- ✏️ `lib/tasks/accounts.rake`
- ✏️ `lib/tasks/invitations.rake`

---

## Summary

✅ **All invitation emails now follow the standardized architecture**
- Database-driven subjects with `{{placeholder}}` support
- Reusable email partials for consistency
- Centralized EmailService for all email sending
- Proper error handling (email failures don't break invitations)
- Easy to maintain and extend

✅ **Backward compatibility maintained**
- All existing functionality works as before
- API endpoints unchanged
- Rake tasks produce same output

✅ **Improved developer experience**
- Single pattern for all emails
- Easy to add new email types
- Better separation of concerns

The email system is now fully consistent across the entire application!
