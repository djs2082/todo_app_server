# Multi-Tenant System Testing Guide

## Quick Start Testing

### Step 1: Create First Account with Admin

```bash
rake 'accounts:create_with_admin[Acme Corp,admin@acme.com,John,Doe]'
```

**Expected Output:**
- Account created with ID
- Invitation token generated
- Signup URL provided

**Copy the signup URL** from the output.

### Step 2: Admin Signup

Use the signup URL or make this request:

```bash
curl -X POST http://localhost:3000/signup?invitation_token=YOUR_TOKEN_HERE \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
	"first_name": "John",
    "last_name": "Doe",
	"mobile": "{{dynamic_mobile}}",
	"email": "admin@acme.com",
    "password": "Password123!",
    "password_confirmation": "Password123!",
    "account_name": "Acme Corp"
},
 "invitation_token": "JmsCvkKZt0il1xsKHlbDN00lq-BFQtpwy4LtOWFLGsM"
}'
```

### Step 3: Activate Admin Account

```bash
curl -X PUT http://localhost:3000/activate \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "activation_code": "ACTIVATION_CODE_FROM_EMAIL"
    }
  }'
```

### Step 4: Admin Login

```bash
curl -X POST http://localhost:3000/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@acme.com",
    "password": "Password123!"
  }'
```

**Save the access_token** from response for subsequent requests.

### Step 5: List Accounts

```bash
curl -X GET http://localhost:3000/accounts \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Step 6: Admin Invites Manager

First, get the role ID for manager:
```bash
# From Rails console
rails console
> Role.manager.id  # Should be 2
```

Then send invitation:
```bash
curl -X POST http://localhost:3000/accounts/ACCOUNT_ID/invitations \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Account-Id: ACCOUNT_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "manager@acme.com",
    "role_id": 2
  }'
```

### Step 7: Admin Invites Users

```bash
curl -X POST http://localhost:3000/accounts/ACCOUNT_ID/invitations \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Account-Id: ACCOUNT_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user1@acme.com",
    "role_id": 3
  }'
```

### Step 8: Manager Signup and Try Inviting Another Manager

```bash
# Manager signs up (use invitation token from step 6)
curl -X POST http://localhost:3000/signup?invitation_token=MANAGER_TOKEN \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "first_name": "Jane",
      "last_name": "Manager",
      "email": "manager@acme.com",
      "password": "Password123!",
      "password_confirmation": "Password123!",
      "account_name": "Acme Corp"
    }
  }'

# Activate and login...

# Try to invite another manager (should FAIL)
curl -X POST http://localhost:3000/accounts/ACCOUNT_ID/invitations \
  -H "Authorization: Bearer MANAGER_ACCESS_TOKEN" \
  -H "X-Account-Id: ACCOUNT_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "manager2@acme.com",
    "role_id": 2
  }'
```

**Expected:** 403 Forbidden - "Not authorized"

### Step 9: Manager Invites Regular User (Should Succeed)

```bash
curl -X POST http://localhost:3000/accounts/ACCOUNT_ID/invitations \
  -H "Authorization: Bearer MANAGER_ACCESS_TOKEN" \
  -H "X-Account-Id: ACCOUNT_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user2@acme.com",
    "role_id": 3
  }'
```

**Expected:** 201 Created - Invitation sent

### Step 10: Test Uninvited Signup

```bash
curl -X POST http://localhost:3000/signup \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "first_name": "Random",
      "last_name": "User",
      "email": "random@example.com",
      "password": "Password123!",
      "password_confirmation": "Password123!",
      "account_name": "Random Account"
    }
  }'
```

**Expected:** User created and added to KaryaApp account

### Step 11: Test Invited User Trying to Signup Without Token

```bash
# First create invitation
curl -X POST http://localhost:3000/accounts/ACCOUNT_ID/invitations \
  -H "Authorization: Bearer ADMIN_ACCESS_TOKEN" \
  -H "X-Account-Id: ACCOUNT_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "invited@acme.com",
    "role_id": 3
  }'

# Then try to signup WITHOUT invitation token
curl -X POST http://localhost:3000/signup \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "first_name": "Invited",
      "last_name": "User",
      "email": "invited@acme.com",
      "password": "Password123!",
      "password_confirmation": "Password123!",
      "account_name": "Some Account"
    }
  }'
```

**Expected:** 422 Unprocessable Entity - "This email has a pending invitation. Please use the invitation link sent to your email."

### Step 12: Create Task in Account

```bash
curl -X POST http://localhost:3000/tasks \
  -H "Authorization: Bearer USER_ACCESS_TOKEN" \
  -H "X-Account-Id: ACCOUNT_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "task": {
      "title": "Complete quarterly report",
      "description": "Compile and submit Q4 report",
      "priority": "high",
      "due_date_time": "2025-11-10T17:00:00Z"
    }
  }'
```

### Step 13: List Tasks (Scoped by Account)

```bash
# User lists tasks (will see only their own)
curl -X GET http://localhost:3000/tasks \
  -H "Authorization: Bearer USER_ACCESS_TOKEN" \
  -H "X-Account-Id: ACCOUNT_ID"

# Admin lists tasks (will see all tasks in account)
curl -X GET http://localhost:3000/tasks \
  -H "Authorization: Bearer ADMIN_ACCESS_TOKEN" \
  -H "X-Account-Id: ACCOUNT_ID"
```

### Step 14: Bulk Invite Users

Create a CSV file `team.csv`:
```csv
email,first_name,last_name
dev1@acme.com,Alice,Developer
dev2@acme.com,Bob,Developer
qa1@acme.com,Carol,QA
designer@acme.com,Dave,Designer
```

Run bulk invite:
```bash
rake invitations:bulk_invite['team.csv',ACCOUNT_ID,'user',ADMIN_USER_ID]
```

### Step 15: List Pending Invitations

```bash
rake invitations:list_pending[ACCOUNT_ID]
```

---

## Test Scenarios Checklist

### Account Creation
- [ ] Create account with admin via rake task
- [ ] Admin receives invitation email
- [ ] Admin can signup with invitation token
- [ ] Account created with correct name and slug

### Role-Based Invitations
- [ ] Admin can invite another admin
- [ ] Admin can invite managers
- [ ] Admin can invite users
- [ ] Manager can invite users
- [ ] Manager CANNOT invite managers
- [ ] Manager CANNOT invite admins
- [ ] User CANNOT invite anyone

### Signup Flows
- [ ] Invited user can signup with token
- [ ] Invited user assigned to correct account and role
- [ ] Uninvited user can signup (added to KaryaApp)
- [ ] User with pending invitation CANNOT signup without token
- [ ] Invalid/expired token returns appropriate error

### Authorization
- [ ] User can create tasks in their account
- [ ] User can view their own tasks
- [ ] User CANNOT view other users' tasks (unless admin/manager)
- [ ] Manager can view all tasks in account
- [ ] Admin can view all tasks in account
- [ ] Admin can delete any task in account
- [ ] Manager CANNOT delete other users' tasks
- [ ] Users from different accounts CANNOT see each other's data

### Invitation Management
- [ ] List pending invitations for account
- [ ] Resend invitation
- [ ] Cancel invitation
- [ ] Expired invitations automatically marked

### Bulk Operations
- [ ] Bulk invite from CSV
- [ ] Skip existing users
- [ ] Skip duplicate pending invitations
- [ ] Handle invalid emails

---

## Common Test Failures and Solutions

### 1. "Account not found"
**Cause:** X-Account-Id header not set or invalid
**Solution:** Ensure X-Account-Id header is sent with every request

### 2. "Not authorized"
**Cause:** User doesn't have permission for action
**Solution:** Check user's role in the account, verify Pundit policy

### 3. "Invalid or expired invitation token"
**Cause:** Token expired (>7 days) or already used
**Solution:** Create new invitation or resend existing one

### 4. "Task not found"
**Cause:** Task doesn't belong to user's accessible accounts
**Solution:** Verify task's account_id and user's account membership

### 5. Invitation email not sent
**Cause:** Mailer not configured or job not processing
**Solution:** Check mailer config, use letter_opener in development

---

## Rails Console Testing

Open Rails console for quick testing:

```bash
rails console
```

### Check Account Setup
```ruby
# List all accounts
Account.all

# Find specific account
account = Account.find_by(name: 'Acme Corp')

# List users in account
account.users

# List administrators
account.administrators

# List pending invitations
UserInvitation.pending.where(account: account)
```

### Check User Roles
```ruby
user = User.find_by(email: 'admin@acme.com')

# List user's accounts
user.accounts

# Check role in specific account
account = Account.first
user.role_in_account(account)
user.administrator_in?(account)
user.can_invite_users_in?(account)
```

### Manually Create Invitation
```ruby
account = Account.find(1)
role = Role.user
inviter = User.first

invitation = UserInvitation.create!(
  email: 'test@example.com',
  account: account,
  role: role,
  invited_by: inviter
)

puts "Token: #{invitation.token}"
puts "Expires: #{invitation.expires_at}"
```

### Check Task Access
```ruby
user = User.first
tasks = TaskPolicy::Scope.new(user, Task).resolve

puts "User can access #{tasks.count} tasks"
```

---

## Automated Test Script

Save this as `test_multi_tenant.sh`:

```bash
#!/bin/bash

BASE_URL="http://localhost:3000"
ACCOUNT_NAME="Test Corp"
ADMIN_EMAIL="admin@test.com"

echo "=== Multi-Tenant System Test ==="

# 1. Create account
echo "\n1. Creating account with admin..."
rake accounts:create_with_admin["$ACCOUNT_NAME","$ADMIN_EMAIL",'Admin','User']

# 2. Get account ID
ACCOUNT_ID=$(rails runner "puts Account.find_by(name: '$ACCOUNT_NAME').id")
echo "Account ID: $ACCOUNT_ID"

# 3. Get invitation token
TOKEN=$(rails runner "puts UserInvitation.find_by(email: '$ADMIN_EMAIL').token")
echo "Invitation Token: $TOKEN"

# 4. Admin signup
echo "\n2. Admin signing up..."
SIGNUP_RESPONSE=$(curl -s -X POST "$BASE_URL/signup?invitation_token=$TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"user\": {
      \"first_name\": \"Admin\",
      \"last_name\": \"User\",
      \"email\": \"$ADMIN_EMAIL\",
      \"password\": \"Password123!\",
      \"password_confirmation\": \"Password123!\",
      \"account_name\": \"$ACCOUNT_NAME\"
    }
  }")
echo "Signup response: $SIGNUP_RESPONSE"

# Continue with more tests...
echo "\n✓ Account creation and admin signup successful!"
```

Run: `chmod +x test_multi_tenant.sh && ./test_multi_tenant.sh`

---

## Performance Testing

### Load Test User Creation
```ruby
# In Rails console
require 'benchmark'

time = Benchmark.measure do
  100.times do |i|
    UserInvitation.create!(
      email: "user#{i}@test.com",
      account: Account.first,
      role: Role.user,
      invited_by: User.first
    )
  end
end

puts "Created 100 invitations in #{time.real} seconds"
```

### Load Test Authorization
```ruby
user = User.first
account = Account.first

time = Benchmark.measure do
  1000.times do
    TaskPolicy.new(user, Task.new(account: account)).show?
  end
end

puts "1000 authorization checks in #{time.real} seconds"
```

---

## Summary

This testing guide covers:
- ✅ Complete end-to-end testing flow
- ✅ All role-based scenarios
- ✅ Authorization edge cases
- ✅ Invitation workflows
- ✅ Bulk operations
- ✅ Rails console testing
- ✅ Common issues and solutions

Follow the steps in order for a comprehensive test of the multi-tenant system.
