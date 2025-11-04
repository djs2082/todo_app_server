# Database Schema Design - Enterprise Todo Application

## Document Information
- **Version:** 1.0
- **Last Updated:** 2025-11-04
- **Status:** Sprint 0 - Design Phase
- **Purpose:** Comprehensive database schema design for multi-tenant enterprise todo application

---

## Table of Contents
1. [Current Schema Overview](#current-schema-overview)
2. [New Tables for Enterprise Features](#new-tables-for-enterprise-features)
3. [Modified Existing Tables](#modified-existing-tables)
4. [Indexes and Performance Optimization](#indexes-and-performance-optimization)
5. [Data Migration Strategy](#data-migration-strategy)
6. [Constraints and Business Rules](#constraints-and-business-rules)
7. [Entity Relationship Diagram](#entity-relationship-diagram)

---

## 1. Current Schema Overview

### 1.1 Existing Tables Summary

| Table | Purpose | Key Relationships |
|-------|---------|-------------------|
| **users** | User authentication & profile | Has many tasks |
| **tasks** | Core task management | Belongs to user |
| **task_pauses** | Pause/resume tracking | Belongs to task |
| **task_events** | Event sourcing for tasks | Belongs to task |
| **task_snapshots** | State snapshots | Belongs to task |
| **events** | System-wide event log | Polymorphic |
| **settings** | Configurable settings | Polymorphic |
| **email_templates** | Email templates | Standalone |
| **jwt_blacklists** | Token revocation | Standalone |

### 1.2 Current Limitations
- No multi-tenancy support (account_name is just a string)
- No role-based access control
- No task assignment capabilities
- No collaboration features
- No AI integration support
- No automation support

---

## 2. New Tables for Enterprise Features

### 2.1 accounts
**Purpose:** Multi-tenant account/organization management

```ruby
create_table :accounts do |t|
  t.string :name, null: false, limit: 100
  t.string :slug, null: false, limit: 100
  t.string :subscription_tier, default: 'free', limit: 20
    # Values: 'free', 'pro', 'enterprise'
  t.string :status, default: 'active', limit: 20
    # Values: 'active', 'suspended', 'canceled', 'trial'

  # Quota limits
  t.integer :max_users, default: 5, null: false
  t.integer :max_tasks_per_user, default: 100, null: false
  t.integer :max_ai_requests_per_month, default: 100, null: false

  # Configuration
  t.json :settings, default: {}
    # Example: { branding: {...}, features: {...}, integrations: {...} }

  # Subscription tracking
  t.datetime :trial_starts_at
  t.datetime :trial_ends_at
  t.datetime :subscription_starts_at
  t.datetime :subscription_ends_at

  # Billing
  t.string :billing_email, limit: 255
  t.string :stripe_customer_id, limit: 100
  t.string :stripe_subscription_id, limit: 100

  # Metadata
  t.string :industry, limit: 50
  t.string :company_size, limit: 20
  t.string :timezone, default: 'UTC', limit: 50

  t.timestamps
  t.datetime :deleted_at
end

# Indexes
add_index :accounts, :slug, unique: true
add_index :accounts, :status
add_index :accounts, :subscription_tier
add_index :accounts, :deleted_at
add_index :accounts, :stripe_customer_id, unique: true, where: "stripe_customer_id IS NOT NULL"
```

**Business Rules:**
- Slug must be URL-safe and unique
- Trial period is 14 days by default
- Free tier: max 5 users, 100 tasks per user
- Pro tier: max 50 users, unlimited tasks
- Enterprise tier: unlimited users and tasks

---

### 2.2 account_memberships
**Purpose:** Links users to accounts with roles

```ruby
create_table :account_memberships do |t|
  t.references :account, null: false, foreign_key: true, index: true
  t.references :user, null: false, foreign_key: true, index: true

  t.string :role, null: false, limit: 20
    # Values: 'owner', 'super_manager', 'manager', 'user'

  # Permissions
  t.boolean :can_reassign_tasks, default: false, null: false
  t.boolean :can_view_analytics, default: false, null: false
  t.boolean :can_manage_members, default: false, null: false

  # Status
  t.string :status, default: 'active', limit: 20
    # Values: 'active', 'inactive', 'pending_invitation'

  # Invitation tracking
  t.string :invitation_token, limit: 100
  t.datetime :invitation_sent_at
  t.datetime :invitation_accepted_at
  t.references :invited_by, foreign_key: { to_table: :users }

  # Membership lifecycle
  t.datetime :joined_at
  t.datetime :left_at

  t.timestamps
end

# Indexes
add_index :account_memberships, [:account_id, :user_id],
          unique: true,
          where: "left_at IS NULL",
          name: 'index_active_memberships_unique'

add_index :account_memberships, [:account_id, :role]
add_index :account_memberships, :invitation_token,
          unique: true,
          where: "invitation_token IS NOT NULL"
add_index :account_memberships, :status
```

**Business Rules:**
- One active membership per user per account
- Owner role: Only one per account, full permissions
- Super Manager: Can manage managers and users
- Manager: Can manage users only
- User: Basic task management only

---

### 2.3 task_assignments
**Purpose:** Track task assignment and delegation history

```ruby
create_table :task_assignments do |t|
  t.references :task, null: false, foreign_key: true, index: true
  t.references :assigned_by, null: false, foreign_key: { to_table: :users }, index: true
  t. :assigned_to, null: false, foreign_key: { to_table: :users }, index: true

  # Assignment lifecycle
  t.datetime :assigned_at, null: false
  t.datetime :accepted_at
  t.datetime :rejected_at
  t.datetime :completed_at
  t.datetime :reassigned_at

  # Rejection tracking
  t.string :rejection_reason, limit: 500
  t.text :rejection_comment

  # Reassignment tracking
  t.integer :reassignment_count, default: 0, null: false
  t.references :reassigned_from, foreign_key: { to_table: :task_assignments }

  # Status
  t.string :status, default: 'pending', limit: 20
    # Values: 'pending', 'accepted', 'rejected', 'completed', 'reassigned'

  # Metadata
  t.json :metadata, default: {}
    # Example: { original_due_date: '...', priority_changed: true }

  t.timestamps
end

# Indexes
add_index :task_assignments, [:task_id, :assigned_to_id, :status]
add_index :task_assignments, [:assigned_to_id, :status, :assigned_at]
add_index :task_assignments, [:assigned_by_id, :assigned_at]
add_index :task_assignments, :reassigned_from_id
add_index :task_assignments, [:task_id, :created_at]
```

**Business Rules:**
- Current assignment = latest active record for task
- Reassignment creates new assignment record
- Original assignment marked as 'reassigned'
- Track full delegation chain via reassigned_from_id

---

### 2.4 notifications
**Purpose:** User notification management

```ruby
create_table :notifications do |t|
  t.references :account, null: false, foreign_key: true, index: true
  t.references :user, null: false, foreign_key: true, index: true

  # Notification content
  t.string :notification_type, null: false, limit: 50
    # Values: 'task_assigned', 'task_due_soon', 'task_overdue',
    #         'task_completed', 'mention', 'comment', 'reminder'
  t.string :title, null: false, limit: 255
  t.text :body
  t.string :action_url, limit: 500

  # Related resource
  t.string :notifiable_type, limit: 50
  t.bigint :notifiable_id

  # Metadata
  t.json :metadata, default: {}
    # Example: { task_id: 123, assigner_name: 'John', due_date: '...' }

  # Delivery tracking
  t.datetime :read_at
  t.datetime :sent_at
  t.datetime :delivered_at
  t.datetime :clicked_at

  # Priority
  t.string :priority, default: 'normal', limit: 20
    # Values: 'low', 'normal', 'high', 'urgent'

  # Channels
  t.boolean :sent_via_email, default: false
  t.boolean :sent_via_push, default: false
  t.boolean :sent_via_websocket, default: false

  t.timestamps
  t.datetime :expires_at
end

# Indexes
add_index :notifications, [:user_id, :read_at]
add_index :notifications, [:user_id, :notification_type, :created_at]
add_index :notifications, [:notifiable_type, :notifiable_id]
add_index :notifications, :expires_at
add_index :notifications, [:account_id, :created_at]
add_index :notifications, [:user_id, :created_at], order: { created_at: :desc }
```

**Business Rules:**
- Unread notifications: read_at IS NULL
- Auto-expire after 30 days
- Support multiple delivery channels
- Track full engagement lifecycle

---

### 2.5 ai_conversations
**Purpose:** Store AI chat conversation sessions

```ruby
create_table :ai_conversations do |t|
  t.references :account, null: false, foreign_key: true, index: true
  t.references :user, null: false, foreign_key: true, index: true

  t.string :conversation_id, null: false, limit: 100
    # UUID or custom ID like 'conv-uuid'

  t.string :status, default: 'active', limit: 20
    # Values: 'active', 'archived', 'deleted'

  t.string :title, limit: 255
    # Auto-generated from first message

  # Context
  t.json :metadata, default: {}
    # Example: { context: 'task_management', user_role: 'manager' }

  # Usage tracking
  t.integer :total_tokens_used, default: 0, null: false
  t.integer :message_count, default: 0, null: false
  t.decimal :total_cost, precision: 10, scale: 4, default: 0.0

  # Lifecycle
  t.datetime :last_message_at
  t.datetime :archived_at

  t.timestamps
end

# Indexes
add_index :ai_conversations, :conversation_id, unique: true
add_index :ai_conversations, [:user_id, :status, :last_message_at]
add_index :ai_conversations, [:account_id, :created_at]
add_index :ai_conversations, [:status, :archived_at]
```

**Business Rules:**
- conversation_id is globally unique UUID
- Auto-archive after 30 days of inactivity
- Track token usage for billing
- Soft delete support

---

### 2.6 ai_messages
**Purpose:** Store individual messages in AI conversations

```ruby
create_table :ai_messages do |t|
  t.references :ai_conversation, null: false, foreign_key: true, index: true

  t.string :role, null: false, limit: 20
    # Values: 'user', 'assistant', 'system', 'function'

  t.text :content, null: false, limit: 10000
    # User input or AI response

  # Function calling
  t.string :function_name, limit: 100
  t.json :function_arguments
  t.json :function_result

  # Metadata
  t.json :metadata, default: {}
    # Example: { model: 'gpt-4o', temperature: 0.7, finish_reason: 'stop' }

  # Token tracking
  t.integer :prompt_tokens, default: 0
  t.integer :completion_tokens, default: 0
  t.integer :total_tokens, default: 0

  # Cost tracking
  t.decimal :cost, precision: 10, scale: 6, default: 0.0

  # Processing
  t.datetime :processed_at
  t.float :processing_time_ms

  t.timestamps
end

# Indexes
add_index :ai_messages, [:ai_conversation_id, :created_at]
add_index :ai_messages, [:role, :created_at]
add_index :ai_messages, :function_name, where: "function_name IS NOT NULL"
add_index :ai_messages, :processed_at
```

**Business Rules:**
- Messages ordered by created_at
- Function messages store call and result
- Track cost per message for billing
- Support streaming messages

---

### 2.7 automation_rules
**Purpose:** Store user-defined automation workflows

```ruby
create_table :automation_rules do |t|
  t.references :account, null: false, foreign_key: true, index: true
  t.references :created_by, null: false, foreign_key: { to_table: :users }, index: true

  t.string :name, null: false, limit: 255
  t.text :description, limit: 1000

  # Trigger configuration
  t.string :trigger_type, null: false, limit: 50
    # Values: 'task_created', 'task_paused', 'task_overdue',
    #         'task_assigned', 'time_based', 'status_changed'

  t.json :trigger_conditions, default: {}
    # Example: { pause_duration_gt: 7200, status: 'paused' }

  # Actions to execute
  t.json :actions, null: false, default: []
    # Example: [
    #   { type: 'send_notification', target: 'manager', template: '...' },
    #   { type: 'update_task', field: 'priority', value: 'high' }
    # ]

  # Status and control
  t.boolean :enabled, default: true, null: false
  t.string :status, default: 'active', limit: 20
    # Values: 'active', 'paused', 'error', 'disabled'

  # Execution tracking
  t.integer :execution_count, default: 0, null: false
  t.integer :success_count, default: 0, null: false
  t.integer :failure_count, default: 0, null: false
  t.datetime :last_executed_at
  t.datetime :last_success_at
  t.datetime :last_failure_at
  t.text :last_error_message

  # Limits
  t.integer :max_executions_per_day, default: 100
  t.integer :executions_today, default: 0

  t.timestamps
  t.datetime :disabled_at
end

# Indexes
add_index :automation_rules, [:account_id, :enabled, :status]
add_index :automation_rules, [:trigger_type, :enabled]
add_index :automation_rules, :created_by_id
add_index :automation_rules, [:enabled, :last_executed_at]
add_index :automation_rules, [:account_id, :execution_count], order: { execution_count: :desc }
```

**Business Rules:**
- Rules evaluated on trigger events
- Disabled after repeated failures (5 consecutive)
- Daily execution limits per tier
- Audit all executions

---

### 2.8 automation_executions
**Purpose:** Audit log for automation rule executions

```ruby
create_table :automation_executions do |t|
  t.references :automation_rule, null: false, foreign_key: true, index: true
  t.references :account, null: false, foreign_key: true, index: true

  # Trigger context
  t.string :triggered_by_type, limit: 50
  t.bigint :triggered_by_id
  t.json :trigger_context, default: {}

  # Execution result
  t.string :status, null: false, limit: 20
    # Values: 'success', 'failure', 'partial', 'skipped'

  t.json :actions_executed, default: []
  t.json :results, default: {}

  # Error tracking
  t.text :error_message
  t.text :error_backtrace

  # Performance
  t.float :execution_time_ms

  t.datetime :executed_at, null: false
  t.timestamps
end

# Indexes
add_index :automation_executions, [:automation_rule_id, :executed_at]
add_index :automation_executions, [:account_id, :status, :executed_at]
add_index :automation_executions, [:triggered_by_type, :triggered_by_id]
add_index :automation_executions, [:status, :executed_at]
```

**Business Rules:**
- Retain execution logs for 90 days
- Archive old executions
- Alert on high failure rates

---

### 2.9 activity_logs
**Purpose:** Comprehensive audit trail for all actions

```ruby
create_table :activity_logs do |t|
  t.references :account, null: false, foreign_key: true, index: true
  t.references :user, foreign_key: true, index: true
    # NULL for system-generated actions

  # Action details
  t.string :action, null: false, limit: 50
    # Values: 'created', 'updated', 'deleted', 'assigned', 'reassigned',
    #         'accepted', 'rejected', 'completed', 'paused', 'resumed'

  # Resource being acted upon
  t.string :resource_type, null: false, limit: 50
  t.bigint :resource_id, null: false

  # Change tracking
  t.json :changes, default: {}
    # Example: { status: ['pending', 'in_progress'], priority: [1, 2] }

  t.json :metadata, default: {}
    # Example: { ip_address: '...', user_agent: '...', reason: '...' }

  # Request context
  t.string :ip_address, limit: 45
  t.string :user_agent, limit: 500
  t.string :request_id, limit: 100

  # Categorization
  t.string :category, limit: 30
    # Values: 'task', 'user', 'account', 'permission', 'ai', 'automation'

  t.timestamps
end

# Indexes
add_index :activity_logs, [:resource_type, :resource_id, :created_at]
add_index :activity_logs, [:account_id, :created_at], order: { created_at: :desc }
add_index :activity_logs, [:user_id, :created_at], order: { created_at: :desc }
add_index :activity_logs, [:action, :resource_type]
add_index :activity_logs, [:category, :created_at]
add_index :activity_logs, :request_id, where: "request_id IS NOT NULL"
```

**Business Rules:**
- Log all sensitive operations
- Retain for 1 year (compliance)
- Support GDPR data export
- Archive to cold storage after 90 days

---

### 2.10 comments
**Purpose:** Task comments and collaboration

```ruby
create_table :comments do |t|
  t.references :task, null: false, foreign_key: true, index: true
  t.references :user, null: false, foreign_key: true, index: true
  t.references :account, null: false, foreign_key: true, index: true

  t.text :body, null: false, limit: 5000

  # Thread support
  t.references :parent_comment, foreign_key: { to_table: :comments }

  # Mentions
  t.json :mentioned_user_ids, default: []

  # Metadata
  t.boolean :is_edited, default: false
  t.datetime :edited_at
  t.references :edited_by, foreign_key: { to_table: :users }

  # Reactions/Attachments
  t.json :reactions, default: {}
    # Example: { thumbs_up: [1, 2, 3], heart: [4, 5] } # user_ids

  t.json :attachments, default: []
    # Example: [{ url: '...', name: '...', size: 1024 }]

  t.timestamps
  t.datetime :deleted_at
end

# Indexes
add_index :comments, [:task_id, :created_at], order: { created_at: :desc }
add_index :comments, [:user_id, :created_at]
add_index :comments, :parent_comment_id
add_index :comments, :deleted_at
add_index :comments, [:account_id, :created_at]
```

**Business Rules:**
- Support nested comments (1 level only)
- Notify mentioned users
- Soft delete support
- Max 5000 characters per comment

---

## 3. Modified Existing Tables

### 3.1 users (Modified)
**Changes:**
- Remove `account_name` string (moved to accounts table)
- Add timezone, language, avatar
- Add preferences

```ruby
# Remove column (via migration)
remove_column :users, :account_name

# Add new columns
change_table :users do |t|
  t.string :timezone, default: 'UTC', limit: 50
  t.string :language, default: 'en', limit: 10
  t.string :avatar_url, limit: 500
  t.json :preferences, default: {}
    # Example: { theme: 'dark', notifications: {...}, email_digest: 'daily' }

  # Enhanced profile
  t.string :job_title, limit: 100
  t.string :department, limit: 100
  t.string :phone, limit: 20

  # Status
  t.boolean :is_active, default: true, null: false
  t.datetime :deactivated_at
  t.datetime :last_activity_at
end

# Add indexes
add_index :users, :is_active
add_index :users, :last_activity_at
```

**Migration Strategy:**
1. Add default_account_id column (nullable)
2. Create accounts from unique account_names
3. Link users to accounts via account_memberships
4. Remove account_name column

---

### 3.2 tasks (Modified)
**Changes:**
- Add account_id for multi-tenancy
- Rename user_id to created_by_id
- Add assigned_to_id
- Add task assignment fields
- Add visibility and collaboration features

```ruby
change_table :tasks do |t|
  # Multi-tenancy
  t.references :account, null: false, foreign_key: true, index: true
    # Add after data migration

  # Rename for clarity
  # user_id → created_by_id (done via rename)

  # Assignment
  t.references :assigned_to, foreign_key: { to_table: :users }, index: true
  t.references :current_assignment, foreign_key: { to_table: :task_assignments }

  # Estimation and tracking
  t.integer :estimated_time, default: 0
    # Estimated time in seconds
  t.integer :actual_time, default: 0
    # Rename from total_working_time

  # Collaboration
  t.string :visibility, default: 'private', limit: 20
    # Values: 'private', 'team', 'account'

  t.json :custom_fields, default: {}
    # Example: { budget: 1000, client: 'Acme Corp' }

  # Recurring tasks
  t.boolean :is_recurring, default: false, null: false
  t.string :recurrence_rule, limit: 500
    # iCal RRULE format: "FREQ=DAILY;INTERVAL=1"
  t.references :parent_task, foreign_key: { to_table: :tasks }

  # Task dependencies
  t.json :depends_on_task_ids, default: []

  # Completion
  t.datetime :completed_at
  t.references :completed_by, foreign_key: { to_table: :users }

  # Tags
  t.json :tags, default: []
    # Example: ['urgent', 'bug-fix', 'client-request']

  # Soft delete
  t.datetime :deleted_at
  t.references :deleted_by, foreign_key: { to_table: :users }
end

# Rename column
rename_column :tasks, :user_id, :created_by_id
rename_column :tasks, :total_working_time, :actual_time

# New indexes
add_index :tasks, [:account_id, :assigned_to_id, :status]
add_index :tasks, [:account_id, :due_date_time]
add_index :tasks, [:account_id, :created_at], order: { created_at: :desc }
add_index :tasks, [:assigned_to_id, :status, :due_date_time]
add_index :tasks, :parent_task_id
add_index :tasks, :visibility
add_index :tasks, :deleted_at
add_index :tasks, [:account_id, :visibility, :status]

# GIN index for JSONB tags (PostgreSQL) or fulltext for MySQL
# For MySQL:
add_index :tasks, :tags, type: :fulltext
```

**Business Rules:**
- created_by_id: Task creator (never changes)
- assigned_to_id: Current assignee (can be NULL or same as creator)
- Account scoping mandatory for all queries
- Soft delete preserves audit trail

---

### 3.3 task_events (Modified)
**Changes:**
- Add account_id for multi-tenancy scoping

```ruby
change_table :task_events do |t|
  t.references :account, null: false, foreign_key: true, index: true
end

add_index :task_events, [:account_id, :created_at]
add_index :task_events, [:account_id, :event_type]
```

---

### 3.4 task_pauses (Modified)
**Changes:**
- Add account_id for multi-tenancy scoping

```ruby
change_table :task_pauses do |t|
  t.references :account, null: false, foreign_key: true, index: true
end

add_index :task_pauses, [:account_id, :created_at]
```

---

### 3.5 task_snapshots (Modified)
**Changes:**
- Add account_id for multi-tenancy scoping

```ruby
change_table :task_snapshots do |t|
  t.references :account, null: false, foreign_key: true, index: true
end

add_index :task_snapshots, [:account_id, :created_at]
```

---

## 4. Indexes and Performance Optimization

### 4.1 Critical Indexes

#### High-Traffic Query Patterns
```sql
-- Get user's assigned tasks
SELECT * FROM tasks
WHERE account_id = ? AND assigned_to_id = ? AND status IN (?)
ORDER BY due_date_time;
-- Index: [:account_id, :assigned_to_id, :status, :due_date_time]

-- Get team tasks for manager
SELECT * FROM tasks
WHERE account_id = ? AND visibility = 'team' AND status IN (?)
ORDER BY priority DESC, due_date_time;
-- Index: [:account_id, :visibility, :status]

-- Get unread notifications
SELECT * FROM notifications
WHERE user_id = ? AND read_at IS NULL
ORDER BY created_at DESC;
-- Index: [:user_id, :read_at, :created_at DESC]

-- Get AI conversation history
SELECT * FROM ai_messages
WHERE ai_conversation_id = ?
ORDER BY created_at;
-- Index: [:ai_conversation_id, :created_at]

-- Get automation rules to evaluate
SELECT * FROM automation_rules
WHERE account_id = ? AND enabled = true AND trigger_type = ?;
-- Index: [:account_id, :enabled, :trigger_type]

-- Activity log for resource
SELECT * FROM activity_logs
WHERE resource_type = ? AND resource_id = ?
ORDER BY created_at DESC;
-- Index: [:resource_type, :resource_id, :created_at DESC]
```

### 4.2 Composite Indexes Strategy

All multi-tenant queries include `account_id` as first column in composite indexes for optimal partition pruning.

### 4.3 JSONB Indexes (PostgreSQL) / JSON Indexes (MySQL)

```sql
-- MySQL 8.0+ supports functional indexes on JSON
-- For tags search
CREATE INDEX idx_tasks_tags ON tasks((CAST(tags AS CHAR(255) ARRAY)));

-- For custom fields search
CREATE INDEX idx_tasks_custom_fields_client
  ON tasks((custom_fields->>'$.client'));
```

### 4.4 Covering Indexes

```sql
-- Tasks list query covering index
CREATE INDEX idx_tasks_list_covering ON tasks(
  account_id, assigned_to_id, status,
  due_date_time, priority, title
);
```

---

## 5. Data Migration Strategy

### Phase 1: Add New Tables (Week 1)
```ruby
# Sprint 1: Migration 001
class CreateAccountsAndMemberships < ActiveRecord::Migration[7.1]
  def change
    create_table :accounts # ... (as defined above)
    create_table :account_memberships # ... (as defined above)
  end
end
```

### Phase 2: Add Foreign Keys (Week 1)
```ruby
# Sprint 1: Migration 002
class AddAccountReferencesToExistingTables < ActiveRecord::Migration[7.1]
  def change
    # Add nullable account_id to all existing tables
    add_reference :tasks, :account, foreign_key: true, null: true
    add_reference :users, :default_account, foreign_key: { to_table: :accounts }, null: true
    add_reference :task_events, :account, foreign_key: true, null: true
    add_reference :task_pauses, :account, foreign_key: true, null: true
    add_reference :task_snapshots, :account, foreign_key: true, null: true
  end
end
```

### Phase 3: Data Migration (Week 1)
```ruby
# Sprint 1: Migration 003
class MigrateUsersToMultiTenancy < ActiveRecord::Migration[7.1]
  def up
    # Get unique account names
    account_names = User.distinct.pluck(:account_name)

    account_names.each do |account_name|
      # Create account
      account = Account.create!(
        name: account_name.titleize,
        slug: account_name.parameterize,
        subscription_tier: 'free',
        status: 'active',
        max_users: 5,
        max_tasks_per_user: 100
      )

      # Find all users with this account_name
      users = User.where(account_name: account_name)

      # Update users
      users.update_all(default_account_id: account.id)

      # Create memberships
      users.each_with_index do |user, index|
        AccountMembership.create!(
          account: account,
          user: user,
          role: index == 0 ? 'owner' : 'user', # First user is owner
          status: 'active',
          joined_at: user.created_at,
          can_reassign_tasks: false,
          can_view_analytics: index == 0,
          can_manage_members: index == 0
        )
      end

      # Update tasks
      user_ids = users.pluck(:id)
      Task.where(user_id: user_ids).update_all(account_id: account.id)

      # Update task_events
      task_ids = Task.where(user_id: user_ids).pluck(:id)
      TaskEvent.where(task_id: task_ids).update_all(account_id: account.id)

      # Update task_pauses
      TaskPause.where(task_id: task_ids).update_all(account_id: account.id)

      # Update task_snapshots
      TaskSnapshot.where(task_id: task_ids).update_all(account_id: account.id)
    end
  end

  def down
    # Rollback: restore account_name from account
    User.includes(:default_account).find_each do |user|
      user.update_column(:account_name, user.default_account.name) if user.default_account
    end

    # Clear references
    Task.update_all(account_id: nil)
    User.update_all(default_account_id: nil)
    TaskEvent.update_all(account_id: nil)
    TaskPause.update_all(account_id: nil)
    TaskSnapshot.update_all(account_id: nil)

    # Delete memberships and accounts
    AccountMembership.delete_all
    Account.delete_all
  end
end
```

### Phase 4: Add NOT NULL Constraints (Week 2)
```ruby
# Sprint 1: Migration 004
class EnforceAccountConstraints < ActiveRecord::Migration[7.1]
  def change
    # Verify all records have account_id
    unless Task.where(account_id: nil).count == 0
      raise "Cannot add NOT NULL constraint: Tasks with NULL account_id exist"
    end

    # Add NOT NULL constraints
    change_column_null :tasks, :account_id, false
    change_column_null :users, :default_account_id, false
    change_column_null :task_events, :account_id, false
    change_column_null :task_pauses, :account_id, false
    change_column_null :task_snapshots, :account_id, false
  end
end
```

### Phase 5: Remove Old Column (Week 2)
```ruby
# Sprint 1: Migration 005
class RemoveAccountNameFromUsers < ActiveRecord::Migration[7.1]
  def up
    # Remove index first
    remove_index :users, :account_name if index_exists?(:users, :account_name)

    # Remove column
    remove_column :users, :account_name
  end

  def down
    add_column :users, :account_name, :string
    add_index :users, :account_name

    # Restore data from account
    User.includes(:default_account).find_each do |user|
      user.update_column(:account_name, user.default_account.name) if user.default_account
    end
  end
end
```

### Phase 6: Rename Columns (Week 2)
```ruby
# Sprint 1: Migration 006
class RenameTaskColumns < ActiveRecord::Migration[7.1]
  def change
    rename_column :tasks, :user_id, :created_by_id
    rename_column :tasks, :total_working_time, :actual_time
  end
end
```

### Phase 7: Add Task Assignment Fields (Week 5-6, Sprint 3)
```ruby
# Sprint 3: Migration 007
class AddTaskAssignmentFields < ActiveRecord::Migration[7.1]
  def change
    add_reference :tasks, :assigned_to, foreign_key: { to_table: :users }
    add_reference :tasks, :current_assignment, foreign_key: { to_table: :task_assignments }

    # Initialize assigned_to from created_by
    reversible do |dir|
      dir.up do
        Task.update_all("assigned_to_id = created_by_id")
      end
    end
  end
end
```

---

## 6. Constraints and Business Rules

### 6.1 Database-Level Constraints

```ruby
# Unique constraints
add_index :accounts, :slug, unique: true
add_index :account_memberships, [:account_id, :user_id],
          unique: true, where: "left_at IS NULL"
add_index :users, :email, unique: true
add_index :ai_conversations, :conversation_id, unique: true

# Check constraints (MySQL 8.0.16+)
execute <<-SQL
  ALTER TABLE accounts
  ADD CONSTRAINT check_subscription_tier
  CHECK (subscription_tier IN ('free', 'pro', 'enterprise'));
SQL

execute <<-SQL
  ALTER TABLE account_memberships
  ADD CONSTRAINT check_role
  CHECK (role IN ('user', 'manager', 'super_manager', 'owner'));
SQL

execute <<-SQL
  ALTER TABLE tasks
  ADD CONSTRAINT check_priority
  CHECK (priority BETWEEN 0 AND 2);
SQL

execute <<-SQL
  ALTER TABLE tasks
  ADD CONSTRAINT check_status
  CHECK (status BETWEEN 0 AND 3);
SQL

# Foreign key constraints with ON DELETE
add_foreign_key :task_assignments, :tasks, on_delete: :cascade
add_foreign_key :task_events, :tasks, on_delete: :cascade
add_foreign_key :task_pauses, :tasks, on_delete: :cascade
add_foreign_key :task_snapshots, :tasks, on_delete: :cascade
add_foreign_key :comments, :tasks, on_delete: :cascade
add_foreign_key :notifications, :accounts, on_delete: :cascade
```

### 6.2 Application-Level Validations

#### Account Model
```ruby
class Account < ApplicationRecord
  SUBSCRIPTION_TIERS = %w[free pro enterprise].freeze
  STATUSES = %w[active suspended canceled trial].freeze

  validates :name, presence: true, length: { maximum: 100 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validates :subscription_tier, inclusion: { in: SUBSCRIPTION_TIERS }
  validates :status, inclusion: { in: STATUSES }
  validates :max_users, numericality: { greater_than: 0 }
  validates :max_tasks_per_user, numericality: { greater_than_or_equal_to: 0 }
end
```

#### AccountMembership Model
```ruby
class AccountMembership < ApplicationRecord
  ROLES = %w[user manager super_manager owner].freeze
  STATUSES = %w[active inactive pending_invitation].freeze

  validates :role, inclusion: { in: ROLES }
  validates :status, inclusion: { in: STATUSES }
  validate :only_one_owner_per_account
  validate :only_one_active_membership_per_user_per_account

  private

  def only_one_owner_per_account
    if role == 'owner' && left_at.nil?
      existing_owner = account.memberships.where(role: 'owner').where.not(id: id).where(left_at: nil).exists?
      errors.add(:role, 'account already has an owner') if existing_owner
    end
  end

  def only_one_active_membership_per_user_per_account
    if left_at.nil?
      existing = AccountMembership.where(account: account, user: user, left_at: nil).where.not(id: id).exists?
      errors.add(:base, 'user already has active membership in this account') if existing
    end
  end
end
```

#### Task Model
```ruby
class Task < ApplicationRecord
  PRIORITIES = { low: 0, medium: 1, high: 2 }.freeze
  STATUSES = { pending: 0, in_progress: 1, paused: 2, completed: 3 }.freeze
  VISIBILITIES = %w[private team account].freeze

  validates :title, presence: true, length: { maximum: 255 }
  validates :priority, inclusion: { in: PRIORITIES.values }
  validates :status, inclusion: { in: STATUSES.values }
  validates :visibility, inclusion: { in: VISIBILITIES }
  validate :account_matches_users

  private

  def account_matches_users
    if account_id.present?
      if created_by && created_by.default_account_id != account_id
        errors.add(:created_by, 'must belong to the same account')
      end

      if assigned_to && assigned_to.default_account_id != account_id
        errors.add(:assigned_to, 'must belong to the same account')
      end
    end
  end
end
```

---

## 7. Entity Relationship Diagram

### 7.1 Core Entities and Relationships

```
┌─────────────────┐
│    accounts     │
│─────────────────│
│ PK: id          │
│ slug (unique)   │
│ subscription    │
│ status          │
└────────┬────────┘
         │
         │ has_many
         ├─────────────────────────────────┐
         │                                 │
         ▼                                 ▼
┌──────────────────────┐          ┌───────────────┐
│ account_memberships  │          │     tasks     │
│──────────────────────│          │───────────────│
│ PK: id               │          │ PK: id        │
│ FK: account_id       │          │ FK: account_id│
│ FK: user_id          │◄─────────┤ FK: created_by│
│ role                 │  belongs │ FK: assigned  │
│ can_reassign_tasks   │    to    │ title         │
└──────────┬───────────┘          │ status        │
           │                      │ priority      │
           │ belongs_to           └───────┬───────┘
           │                              │
           ▼                              │ has_many
┌─────────────────┐                       │
│      users      │                       ├────────────────────────┐
│─────────────────│                       │                        │
│ PK: id          │                       ▼                        ▼
│ email (unique)  │              ┌──────────────────┐    ┌─────────────────┐
│ first_name      │              │ task_assignments │    │   comments      │
│ last_name       │              │──────────────────│    │─────────────────│
│ timezone        │              │ PK: id           │    │ PK: id          │
│ preferences     │              │ FK: task_id      │    │ FK: task_id     │
└────────┬────────┘              │ FK: assigned_by  │    │ FK: user_id     │
         │                       │ FK: assigned_to  │    │ body            │
         │ has_many              │ status           │    │ mentioned_users │
         │                       │ assigned_at      │    └─────────────────┘
         ├───────────────────────┤ accepted_at      │
         │                       └──────────────────┘
         │
         ├───────────────────────┐
         │                       │
         ▼                       ▼
┌──────────────────┐    ┌──────────────────┐
│ ai_conversations │    │  notifications   │
│──────────────────│    │──────────────────│
│ PK: id           │    │ PK: id           │
│ FK: account_id   │    │ FK: account_id   │
│ FK: user_id      │    │ FK: user_id      │
│ conversation_id  │    │ type             │
│ status           │    │ title            │
└────────┬─────────┘    │ read_at          │
         │              └──────────────────┘
         │ has_many
         │
         ▼
┌──────────────────┐
│   ai_messages    │
│──────────────────│
│ PK: id           │
│ FK: conversation │
│ role             │
│ content          │
│ function_name    │
│ total_tokens     │
└──────────────────┘

┌──────────────────┐
│ automation_rules │
│──────────────────│
│ PK: id           │
│ FK: account_id   │
│ FK: created_by   │
│ trigger_type     │
│ actions (JSON)   │
│ enabled          │
└────────┬─────────┘
         │ has_many
         ▼
┌──────────────────────┐
│ automation_executions│
│──────────────────────│
│ PK: id               │
│ FK: automation_rule  │
│ status               │
│ executed_at          │
└──────────────────────┘

┌──────────────────┐
│  activity_logs   │
│──────────────────│
│ PK: id           │
│ FK: account_id   │
│ FK: user_id      │
│ action           │
│ resource_type    │
│ resource_id      │
│ changes (JSON)   │
└──────────────────┘
```

### 7.2 Relationship Cardinality

| Relationship | Type | Cardinality |
|--------------|------|-------------|
| Account → AccountMemberships | 1:N | One account has many memberships |
| User → AccountMemberships | 1:N | One user can be in many accounts |
| Account → Tasks | 1:N | One account has many tasks |
| User (created_by) → Tasks | 1:N | One user creates many tasks |
| User (assigned_to) → Tasks | 1:N | One user is assigned many tasks |
| Task → TaskAssignments | 1:N | One task has many assignments (history) |
| Task → Comments | 1:N | One task has many comments |
| Task → TaskEvents | 1:N | One task has many events |
| User → AIConversations | 1:N | One user has many conversations |
| AIConversation → AIMessages | 1:N | One conversation has many messages |
| Account → AutomationRules | 1:N | One account has many automation rules |
| AutomationRule → AutomationExecutions | 1:N | One rule has many executions |

---

## 8. Database Size Estimation

### Assumptions
- 100 accounts
- Average 20 users per account = 2,000 users
- Average 500 tasks per user = 1,000,000 tasks
- Average 10 events per task = 10,000,000 task_events
- Average 5 pauses per task = 5,000,000 task_pauses
- Average 3 comments per task = 3,000,000 comments
- Average 5 notifications per user per day × 365 days = 3,650,000 notifications
- Average 100 AI conversations per user = 200,000 conversations
- Average 20 messages per conversation = 4,000,000 ai_messages

### Table Size Estimates (MySQL InnoDB)

| Table | Rows | Avg Row Size | Estimated Size |
|-------|------|--------------|----------------|
| accounts | 100 | 1 KB | 100 KB |
| account_memberships | 2,000 | 500 B | 1 MB |
| users | 2,000 | 1 KB | 2 MB |
| tasks | 1,000,000 | 2 KB | 2 GB |
| task_assignments | 1,500,000 | 500 B | 750 MB |
| task_events | 10,000,000 | 1 KB | 10 GB |
| task_pauses | 5,000,000 | 500 B | 2.5 GB |
| task_snapshots | 5,000,000 | 1 KB | 5 GB |
| comments | 3,000,000 | 1 KB | 3 GB |
| notifications | 3,650,000 | 500 B | 1.8 GB |
| ai_conversations | 200,000 | 500 B | 100 MB |
| ai_messages | 4,000,000 | 2 KB | 8 GB |
| automation_rules | 1,000 | 1 KB | 1 MB |
| automation_executions | 10,000,000 | 500 B | 5 GB |
| activity_logs | 20,000,000 | 1 KB | 20 GB |

**Total Data:** ~58 GB
**Indexes:** ~30% overhead = ~18 GB
**Total Database Size:** ~76 GB

### Growth Projection (Year 1)
- 10x growth in tasks = 580 GB
- Recommend archiving strategy for logs older than 90 days
- Partition large tables by date (task_events, activity_logs, notifications)

---

## 9. Performance Considerations

### 9.1 Query Optimization

- All queries scoped by `account_id` (tenant isolation)
- Use `includes` for N+1 prevention
- Implement query result caching (Redis)
- Use counter caches for counts
- Implement read replicas for heavy read queries

### 9.2 Partitioning Strategy

```sql
-- Partition activity_logs by month
ALTER TABLE activity_logs
PARTITION BY RANGE (YEAR(created_at) * 100 + MONTH(created_at)) (
  PARTITION p202501 VALUES LESS THAN (202502),
  PARTITION p202502 VALUES LESS THAN (202503),
  -- ... monthly partitions
  PARTITION pmax VALUES LESS THAN MAXVALUE
);

-- Partition notifications by month
ALTER TABLE notifications
PARTITION BY RANGE (YEAR(created_at) * 100 + MONTH(created_at)) (
  PARTITION p202501 VALUES LESS THAN (202502),
  PARTITION p202502 VALUES LESS THAN (202503),
  -- ... monthly partitions
  PARTITION pmax VALUES LESS THAN MAXVALUE
);
```

### 9.3 Archival Strategy

- Archive activity_logs older than 90 days to cold storage (S3)
- Archive notifications older than 30 days
- Archive automation_executions older than 90 days
- Implement soft delete for tasks, preserve for 30 days before hard delete

---

## 10. Security Considerations

### 10.1 Row-Level Security

- All queries MUST include `account_id` filter
- Implement `acts_as_tenant` gem for automatic scoping
- Use Pundit policies for authorization
- Audit all cross-account queries

### 10.2 Encryption

- Encrypt sensitive columns: password_digest, reset_password_token, stripe_customer_id
- Use `attr_encrypted` gem for application-level encryption
- Enable MySQL encryption at rest
- TLS 1.3 for all connections

### 10.3 Audit Requirements

- Log all DELETE operations
- Log all role changes
- Log all task assignments/reassignments
- Retain audit logs for 1 year (compliance)

---

## Summary

This database schema design provides:

✅ **Multi-tenancy:** Complete account isolation with `account_id` scoping
✅ **Scalability:** Optimized indexes and partitioning strategy
✅ **Flexibility:** JSONB fields for extensibility
✅ **Audit Trail:** Comprehensive activity logging
✅ **Performance:** Strategic indexes and query optimization
✅ **Security:** Row-level security and encryption
✅ **Data Integrity:** Foreign keys and check constraints
✅ **Migration Safety:** Phased migration with rollback support

**Next Steps:**
1. Review and approve schema design
2. Implement Phase 1 migrations (Sprint 1)
3. Set up multi-tenancy gem (`acts_as_tenant`)
4. Create database migration scripts
5. Test migrations on production copy
6. Execute data migration
7. Validate data integrity

---

**Document Version History:**
- v1.0 (2025-11-04): Initial schema design for Sprint 0
