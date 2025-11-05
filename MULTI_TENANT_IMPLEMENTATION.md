# Multi-Tenant Account System Implementation Guide

## Overview
This document describes the complete multi-tenant account system with role-based access control (RBAC) implemented in the KaryaApp Rails application.

## Features Implemented

### 1. Multi-Tenant Architecture
- **Accounts**: Multiple organizations can use the application
- **Roles**: Three role types - Administrator, Manager, User
- **Invitation System**: Email-based user invitations with tokens
- **Default Account**: KaryaApp account for uninvited signups
- **Authorization**: Pundit-based policy enforcement

---

## Database Schema

### New Tables

#### accounts
- `id` (bigint, primary key)
- `name` (string, not null, unique) - Account name
- `slug` (string, not null, unique) - URL-friendly identifier
- `active` (boolean, default: true, not null) - Account status
- `created_at`, `updated_at` (datetime)

#### roles
- `id` (bigint, primary key)
- `name` (string, not null, unique) - Role name (administrator/manager/user)
- `description` (string) - Role description
- `created_at`, `updated_at` (datetime)

**Default Roles Created:**
- `administrator` - Full account access, can manage managers and users
- `manager` - Can manage users but not other managers
- `user` - Basic access, can manage own tasks

#### account_users (Join Table)
- `id` (bigint, primary key)
- `user_id` (bigint, not null, foreign key to users)
- `account_id` (bigint, not null, foreign key to accounts)
- `role_id` (bigint, not null, foreign key to roles)
- `active` (boolean, default: true, not null)
- `created_at`, `updated_at` (datetime)
- **Unique Index**: `[user_id, account_id]` - One role per account per user

#### user_invitations
- `id` (bigint, primary key)
- `email` (string, not null)
- `token` (string, not null, unique) - Invitation token
- `account_id` (bigint, not null, foreign key to accounts)
- `role_id` (bigint, not null, foreign key to roles)
- `invited_by_id` (bigint, foreign key to users) - Who sent the invitation
- `expires_at` (datetime, not null) - Token expiry (7 days default)
- `accepted_at` (datetime) - When invitation was accepted
- `status` (string, default: 'pending', not null) - pending/accepted/expired/cancelled
- `created_at`, `updated_at` (datetime)

### Modified Tables

#### tasks
- Added `account_id` (bigint, not null, foreign key to accounts)
- All existing tasks backfilled with KaryaApp account

---

## Models

### Account (`app/models/account.rb`)
**Associations:**
- `has_many :account_users`
- `has_many :users, through: :account_users`
- `has_many :tasks`
- `has_many :user_invitations`

**Key Methods:**
- `karyaapp_account` - Get or create default KaryaApp account
- `add_user(user, role)` - Add user with role to account
- `remove_user(user)` - Remove user from account
- `user_role(user)` - Get user's role in this account
- `administrators`, `managers`, `regular_users` - Scoped user lists

### Role (`app/models/role.rb`)
**Constants:**
- `ADMINISTRATOR = 'administrator'`
- `MANAGER = 'manager'`
- `USER = 'user'`

**Key Methods:**
- `administrator?`, `manager?`, `user?` - Role checking
- `can_invite_users?` - Can role invite users? (admin/manager)
- `can_invite_managers?` - Can role invite managers? (admin only)

### AccountUser (`app/models/account_user.rb`)
Join model connecting users to accounts with roles.

**Key Methods:**
- `activate!` / `deactivate!` - Toggle user's account access
- Delegates: `role_name`, `account_name`

### UserInvitation (`app/models/user_invitation.rb`)
**Constants:**
- `TOKEN_EXPIRY_DAYS = 7`

**Key Methods:**
- `find_valid_invitation(token)` - Find and validate invitation
- `expired?` - Check if invitation expired
- `mark_as_accepted!` / `mark_as_expired!` / `mark_as_cancelled!` - Status management

### User (Updated: `app/models/user.rb`)
**New Associations:**
- `has_many :account_users`
- `has_many :accounts, through: :account_users`
- `has_many :roles, through: :account_users`
- `has_many :sent_invitations`

**New Methods:**
- `role_in_account(account)` - Get role for specific account
- `administrator_in?(account)` - Is admin in this account?
- `manager_in?(account)` - Is manager in this account?
- `belongs_to_account?(account)` - Member of this account?
- `primary_account` - Get user's first active account
- `can_invite_users_in?(account)` - Can invite users to this account?
- `can_invite_managers_in?(account)` - Can invite managers to this account?

### Task (Updated: `app/models/task.rb`)
**New Association:**
- `belongs_to :account`

---

## Controllers

### ApplicationController (Updated)
**New Includes:**
- `Pundit::Authorization` - Authorization framework

**New Methods:**
- `current_account` - Get account from X-Account-Id header or user's primary account
- `pundit_user` - Required for Pundit
- `user_not_authorized(exception)` - Handle authorization failures

### UsersController (Updated: `app/controllers/users_controller.rb`)
**Updated `signup` Action:**
- Accepts optional `invitation_token` parameter
- Validates invitation token if provided
- Checks for pending invitations for the email
- Assigns user to:
  - Invitation's account with specified role (if invited)
  - KaryaApp account as regular user (if not invited)
- Rejects signup if:
  - Invalid/expired invitation token provided
  - Email has pending invitation but no token used

### UserInvitationsController (New: `app/controllers/user_invitations_controller.rb`)
**Actions:**
- `GET /accounts/:account_id/invitations` - List invitations for account
- `POST /accounts/:account_id/invitations` - Create invitation
- `GET /invitations/:id` - Show invitation details
- `DELETE /invitations/:id` - Cancel invitation
- `POST /invitations/:id/resend` - Resend invitation email

**Authorization:**
- Admins can invite anyone
- Managers can invite only users (not managers/admins)
- Can only see/manage invitations in their accounts

### AccountsController (New: `app/controllers/accounts_controller.rb`)
**Actions:**
- `GET /accounts` - List user's accounts
- `GET /accounts/:id` - Show account details with users and roles

### TasksController (Updated: `app/controllers/tasks_controller.rb`)
**Changes:**
- Added Pundit authorization to all actions
- Uses `policy_scope(Task)` for index and find
- Sets `account` from `current_account` on create
- Includes account info in responses
- Enforces permissions:
  - Users can manage their own tasks
  - Admins/Managers can view/edit all account tasks
  - Only admins can delete other users' tasks

---

## Pundit Policies

### AccountPolicy (`app/policies/account_policy.rb`)
**Permissions:**
- `index?` - All users can list their accounts
- `show?` - Can view if member of account
- `update?`, `destroy?` - Administrators only
- `invite_users?` - Administrators and Managers
- `invite_managers?` - Administrators only

### TaskPolicy (`app/policies/task_policy.rb`)
**Permissions:**
- Users can see their own tasks + tasks in managed accounts
- `show?`, `update?`, start/pause/resume/complete - Own tasks OR admin/manager in account
- `destroy?` - Own tasks OR administrator in account

### UserInvitationPolicy (`app/policies/user_invitation_policy.rb`)
**Permissions:**
- `create?` - Based on role and target role
  - Admins can invite anyone
  - Managers can only invite users
- `destroy?`, `resend?` - Own invitations OR administrator in account

---

## Mailers

### UserInvitationMailer (`app/mailers/user_invitation_mailer.rb`)
**Methods:**
- `invite_user(invitation)` - Send user/manager invitation
- `invite_admin(invitation)` - Send administrator invitation (special template)

**Email Templates:**
- `app/views/user_invitation_mailer/invite_user.html.erb`
- `app/views/user_invitation_mailer/invite_admin.html.erb`

**Configuration:**
- Set `MAILER_FROM_EMAIL` environment variable (default: noreply@karyaapp.com)
- Set `FRONTEND_URL` environment variable for signup links

---

## Rake Tasks

### Account Management (`lib/tasks/accounts.rake`)

#### Create Account with Admin
```bash
rake accounts:create_with_admin['Acme Corp','admin@acme.com','John','Doe']
```
Creates:
- New account
- Admin invitation
- Sends invitation email
- Outputs signup URL

#### List Accounts
```bash
rake accounts:list
```
Shows all accounts with their users and roles.

#### Activate/Deactivate Account
```bash
rake accounts:activate[1]
rake accounts:deactivate[1]
```

### Invitation Management (`lib/tasks/invitations.rake`)

#### Bulk Invite from CSV
```bash
rake invitations:bulk_invite['users.csv',1,'user',1]
```
**CSV Format:**
```csv
email,first_name,last_name
user1@example.com,John,Doe
user2@example.com,Jane,Smith
```

**Arguments:**
- `csv_file` - Path to CSV file
- `account_id` - Target account ID
- `role_name` - administrator/manager/user
- `inviter_id` - User ID sending invitations (optional)

#### List Pending Invitations
```bash
rake invitations:list_pending[1]
```

#### Cancel Invitation
```bash
rake invitations:cancel[123]
```

#### Expire Old Invitations
```bash
rake invitations:expire_old
```
Marks all expired pending invitations as expired.

---

## API Routes

### Authentication & Users
```
POST   /signup                           # Signup (with optional invitation_token param)
PUT    /activate                         # Activate account
POST   /login                            # Login
POST   /refresh                          # Refresh token
POST   /logout                           # Logout
GET    /users                            # List users
GET    /users/:id                        # Show user
```

### Accounts
```
GET    /accounts                         # List user's accounts
GET    /accounts/:id                     # Show account details
```

### Invitations
```
GET    /accounts/:account_id/invitations # List account invitations
POST   /accounts/:account_id/invitations # Create invitation
GET    /invitations/:id                  # Show invitation
DELETE /invitations/:id                  # Cancel invitation
POST   /invitations/:id/resend           # Resend invitation
```

### Tasks
```
GET    /tasks                            # List tasks (scoped by account access)
POST   /tasks                            # Create task (in current account)
GET    /tasks/:id                        # Show task (with authorization)
PATCH  /tasks/:id                        # Update task (with authorization)
DELETE /tasks/:id                        # Delete task (with authorization)
POST   /tasks/:id/start                  # Start task
POST   /tasks/:id/pause                  # Pause task
POST   /tasks/:id/resume                 # Resume task
POST   /tasks/:id/complete               # Complete task
```

---

## Request/Response Examples

### 1. Create Account with Admin (Rake Task)
```bash
rake accounts:create_with_admin['Acme Corp','admin@acme.com','John','Doe']
```

**Output:**
```
✓ Created account: Acme Corp (ID: 2)
✓ Created invitation for admin: admin@acme.com
✓ Sent invitation email to: admin@acme.com

============================================================
ACCOUNT CREATED SUCCESSFULLY
============================================================
Account Name: Acme Corp
Account Slug: acme-corp
Admin Email: admin@acme.com
Invitation Token: ABC123XYZ...
Invitation Expires: 2025-11-12 12:00:00 UTC

Signup URL:
http://localhost:3000/signup?invitation_token=ABC123XYZ...
============================================================
```

### 2. Admin Self-Signup (Using Invitation)
```bash
POST /signup?invitation_token=ABC123XYZ...
Content-Type: application/json

{
  "user": {
    "first_name": "John",
    "last_name": "Doe",
    "email": "admin@acme.com",
    "password": "SecurePass123!",
    "password_confirmation": "SecurePass123!",
    "account_name": "Acme Corp"
  }
}
```

**Response:**
```json
{
  "message": "Signup successful! Please check your email for activation instructions.",
  "data": {
    "id": 5,
    "account": "Acme Corp"
  }
}
```

### 3. Admin Invites Manager
```bash
POST /accounts/2/invitations
Authorization: Bearer <admin_jwt_token>
X-Account-Id: 2
Content-Type: application/json

{
  "email": "manager@acme.com",
  "role_id": 2
}
```

**Response:**
```json
{
  "message": "Invitation sent successfully",
  "data": {
    "id": 10,
    "email": "manager@acme.com",
    "token": "XYZ789ABC...",
    "status": "pending",
    "expires_at": "2025-11-12T12:00:00.000Z",
    "role": {
      "id": 2,
      "name": "manager"
    },
    "account": {
      "id": 2,
      "name": "Acme Corp"
    }
  }
}
```

### 4. Manager Invites User
```bash
POST /accounts/2/invitations
Authorization: Bearer <manager_jwt_token>
X-Account-Id: 2
Content-Type: application/json

{
  "email": "user@acme.com",
  "role_id": 3
}
```

**Response:** (Same as above, but role is "user")

### 5. User Self-Signup (No Invitation)
```bash
POST /signup
Content-Type: application/json

{
  "user": {
    "first_name": "Random",
    "last_name": "User",
    "email": "random@example.com",
    "password": "Password123!",
    "password_confirmation": "Password123!",
    "account_name": "Random User Account"
  }
}
```

**Response:**
```json
{
  "message": "Signup successful! Please check your email for activation instructions.",
  "data": {
    "id": 6,
    "account": "KaryaApp"
  }
}
```
*Note: User is automatically added to KaryaApp account as regular user*

### 6. User Tries to Signup Without Invitation Token (But Has Pending Invitation)
```bash
POST /signup
Content-Type: application/json

{
  "user": {
    "first_name": "Invited",
    "last_name": "User",
    "email": "invited@acme.com",
    "password": "Password123!",
    "password_confirmation": "Password123!",
    "account_name": "Some Account"
  }
}
```

**Response:**
```json
{
  "message": "This email has a pending invitation. Please use the invitation link sent to your email.",
  "errors": []
}
```

### 7. Create Task in Account
```bash
POST /tasks
Authorization: Bearer <user_jwt_token>
X-Account-Id: 2
Content-Type: application/json

{
  "task": {
    "title": "Complete project proposal",
    "description": "Draft and finalize the Q1 project proposal",
    "priority": "high",
    "due_date_time": "2025-11-10T17:00:00Z"
  }
}
```

**Response:**
```json
{
  "message": "Task created",
  "data": {
    "id": 42,
    "account_id": 2
  }
}
```

### 8. List Tasks (Scoped by Account Access)
```bash
GET /tasks
Authorization: Bearer <user_jwt_token>
X-Account-Id: 2
```

**Response:**
Returns tasks the user has access to:
- Own tasks
- All tasks in accounts where user is admin/manager

### 9. Bulk Invite Users (Rake Task)
```bash
rake invitations:bulk_invite['team.csv',2,'user',5]
```

**CSV File (team.csv):**
```csv
email,first_name,last_name
dev1@acme.com,Alice,Developer
dev2@acme.com,Bob,Developer
qa1@acme.com,Carol,QA
```

**Output:**
```
============================================================
BULK USER INVITATION
============================================================
Account: Acme Corp
Role: User
Inviter: John Doe
File: team.csv
============================================================

Processing invitations...

✓ Invited: dev1@acme.com
✓ Invited: dev2@acme.com
✓ Invited: qa1@acme.com

============================================================
BULK INVITATION SUMMARY
============================================================
Successfully invited: 3
Skipped: 0
Errors: 0
============================================================
```

---

## Authorization Rules Summary

### Account-Level Permissions

| Action | Administrator | Manager | User |
|--------|--------------|---------|------|
| View account | ✓ | ✓ | ✓ |
| Update account | ✓ | ✗ | ✗ |
| Invite users | ✓ | ✓ | ✗ |
| Invite managers | ✓ | ✗ | ✗ |
| Invite admins | ✓ | ✗ | ✗ |
| Remove users | ✓ | ✓ (users only) | ✗ |
| View all tasks | ✓ | ✓ | Own only |
| Delete any task | ✓ | ✗ | Own only |

### Task Permissions

| Action | Own Task | Admin (Same Account) | Manager (Same Account) | Different Account |
|--------|----------|---------------------|----------------------|------------------|
| View | ✓ | ✓ | ✓ | ✗ |
| Create | ✓ | ✓ | ✓ | ✗ |
| Update | ✓ | ✓ | ✓ | ✗ |
| Delete | ✓ | ✓ | ✗ | ✗ |
| Start/Pause/Resume | ✓ | ✓ | ✓ | ✗ |

---

## Environment Variables

Add these to your `.env` file:

```bash
# Mailer Configuration
MAILER_FROM_EMAIL=noreply@karyaapp.com

# Frontend URL for invitation links
FRONTEND_URL=http://localhost:3000

# JWT Configuration (existing)
JWT_SECRET=your_jwt_secret_here
```

---

## Testing the Implementation

### 1. Setup Test Account
```bash
# Create account with admin
rake accounts:create_with_admin['Test Corp','admin@test.com','Admin','User']

# Note the invitation URL and use it to signup
```

### 2. Test Admin Flow
```bash
# 1. Admin signs up using invitation URL
# 2. Admin activates account
# 3. Admin logs in
# 4. Admin invites a manager
# 5. Admin invites users
```

### 3. Test Manager Flow
```bash
# 1. Manager signs up using invitation
# 2. Manager logs in
# 3. Manager tries to invite another manager (should fail)
# 4. Manager invites regular users (should succeed)
```

### 4. Test User Flow
```bash
# 1. User signs up using invitation
# 2. User creates tasks in their account
# 3. User tries to invite others (should fail)
```

### 5. Test Uninvited Signup
```bash
# 1. Random user signs up without invitation
# 2. Verify user is added to KaryaApp account
# 3. User can create tasks in KaryaApp account
```

---

## Security Considerations

1. **Invitation Tokens**
   - 32-byte URL-safe tokens
   - 7-day expiry
   - One-time use (marked as accepted)

2. **Authorization**
   - Pundit policies enforced on all controller actions
   - Users can only access accounts they belong to
   - Role-based permissions strictly enforced

3. **Account Isolation**
   - Tasks are scoped by account
   - Users can only see data from their accounts
   - Cross-account access prevented by policies

4. **Email Validation**
   - Pending invitations prevent unauthorized signups
   - Email verification required for all users

---

## Future Enhancements

1. **Account Settings**
   - Custom branding per account
   - Feature toggles per account
   - Usage limits and quotas

2. **Advanced Permissions**
   - Custom roles beyond the three defaults
   - Granular permissions per resource
   - Team-based permissions

3. **Account Management UI**
   - User management dashboard
   - Invitation management
   - Activity logs

4. **Billing Integration**
   - Per-account billing
   - Usage tracking
   - Plan management

5. **Audit Logs**
   - Track all account changes
   - User action history
   - Security audit trail

---

## Troubleshooting

### Issue: Invitation email not sending
**Solution:** Check your mailer configuration and ensure SMTP is configured or use letter_opener in development.

### Issue: User can't see tasks
**Solution:** Verify user belongs to the account (check account_users table) and X-Account-Id header is set.

### Issue: Authorization failures
**Solution:** Check Pundit policies and ensure user has correct role in the account.

### Issue: Migrations fail
**Solution:** Ensure you're running migrations in order. Drop and recreate database if needed.

---

## Summary

This implementation provides a complete multi-tenant account system with:
- ✅ Multiple accounts with isolated data
- ✅ Role-based access control (Administrator, Manager, User)
- ✅ Invitation-based user onboarding
- ✅ Default KaryaApp account for public signups
- ✅ Email-based invitations with 7-day expiry
- ✅ Pundit-based authorization
- ✅ Rake tasks for account and bulk user management
- ✅ Account-scoped tasks with proper authorization
- ✅ Comprehensive API endpoints
- ✅ Proper error handling and validation

The system is production-ready and follows Rails best practices.
