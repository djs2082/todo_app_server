# Project Board & Task Tracking Setup

## Document Information
- **Version:** 1.0
- **Last Updated:** 2025-11-04
- **Status:** Sprint 0 - Project Management Configuration
- **Purpose:** Guide for setting up project boards and task tracking

---

## Table of Contents
1. [Overview](#overview)
2. [GitHub Projects Setup](#github-projects-setup)
3. [Board Structure](#board-structure)
4. [Workflow Automation](#workflow-automation)
5. [Issue Templates](#issue-templates)
6. [Labels and Organization](#labels-and-organization)
7. [Sprint Planning](#sprint-planning)
8. [Reporting and Metrics](#reporting-and-metrics)

---

## Overview

### Project Management Stack

```
┌──────────────────────────────────────────────────────┐
│            GitHub Projects (Kanban Board)             │
│                                                       │
│  Backlog → Todo → In Progress → Review → Done       │
└────────────────────┬─────────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
        ▼            ▼            ▼
┌──────────────┐ ┌──────────┐ ┌──────────┐
│   Issues     │ │   PRs    │ │Milestones│
│  (Tasks)     │ │ (Code)   │ │(Sprints) │
└──────────────┘ └──────────┘ └──────────┘
```

### Tools

| Tool | Purpose | Link |
|------|---------|------|
| **GitHub Projects** | Kanban board, sprint tracking | https://github.com/your-org/todo_app_server/projects |
| **GitHub Issues** | Task tracking, bug reports | https://github.com/your-org/todo_app_server/issues |
| **GitHub Milestones** | Sprint tracking | https://github.com/your-org/todo_app_server/milestones |
| **GitHub Actions** | Automation | https://github.com/your-org/todo_app_server/actions |

---

## GitHub Projects Setup

### Step 1: Create New Project

```bash
# Go to your repository
https://github.com/your-org/todo_app_server

# Click "Projects" tab
# Click "New project"
# Choose "Board" template
# Name: "TodoApp Backend Development"
```

### Step 2: Configure Board Views

Create these views:

**1. Sprint Board (Default)**
- Group by: Status
- Sort by: Priority
- Filter: Current milestone

**2. Backlog**
- Group by: Priority
- Sort by: Created date
- Filter: No milestone

**3. By Assignee**
- Group by: Assignee
- Sort by: Status
- Filter: In progress

**4. By Sprint**
- Group by: Milestone
- Sort by: Due date
- Filter: All

---

## Board Structure

### Columns (Statuses)

| Column | Description | Automation |
|--------|-------------|------------|
| **Backlog** | Ideas, future work | Issues without milestone |
| **Todo** | Ready for development | Issues in current milestone |
| **In Progress** | Currently being worked on | Auto-move on PR creation |
| **In Review** | Code review in progress | Auto-move when PR ready |
| **Done** | Completed and merged | Auto-move on PR merge |
| **Blocked** | Waiting on dependencies | Manual |

### Card Types

**Issue Cards:**
- Task
- Bug
- Feature
- Enhancement
- Documentation

**Pull Request Cards:**
- Automatically linked to issues
- Show review status
- Show CI status

---

## Workflow Automation

### GitHub Actions for Project Management

Create `.github/workflows/project-automation.yml`:

```yaml
name: Project Automation

on:
  issues:
    types: [opened, closed, reopened]
  pull_request:
    types: [opened, ready_for_review, closed]
  project_card:
    types: [moved]

jobs:
  automate:
    runs-on: ubuntu-latest
    steps:
      - name: Move issue to "In Progress" when PR is opened
        uses: alex-page/github-project-automation-plus@v0.8.3
        if: github.event_name == 'pull_request' && github.event.action == 'opened'
        with:
          project: TodoApp Backend Development
          column: In Progress
          repo-token: ${{ secrets.GITHUB_TOKEN }}

      - name: Move to "In Review" when PR is ready
        uses: alex-page/github-project-automation-plus@v0.8.3
        if: github.event_name == 'pull_request' && github.event.action == 'ready_for_review'
        with:
          project: TodoApp Backend Development
          column: In Review
          repo-token: ${{ secrets.GITHUB_TOKEN }}

      - name: Move to "Done" when PR is merged
        uses: alex-page/github-project-automation-plus@v0.8.3
        if: github.event_name == 'pull_request' && github.event.action == 'closed' && github.event.pull_request.merged == true
        with:
          project: TodoApp Backend Development
          column: Done
          repo-token: ${{ secrets.GITHUB_TOKEN }}
```

### Manual Automations

**Adding issues to project:**
```bash
# Automatically add new issues to project
Settings → Projects → Auto-add to project
```

**Auto-labeling:**
```bash
# Use .github/labeler.yml for automatic labeling based on files changed
```

---

## Issue Templates

### Create Template Files

**Directory structure:**
```
.github/
└── ISSUE_TEMPLATE/
    ├── bug_report.md
    ├── feature_request.md
    ├── task.md
    └── config.yml
```

### Bug Report Template

**File:** `.github/ISSUE_TEMPLATE/bug_report.md`

```markdown
---
name: Bug Report
about: Report a bug to help us improve
title: '[BUG] '
labels: bug, needs-triage
assignees: ''
---

## Bug Description
A clear and concise description of the bug.

## Steps to Reproduce
1. Go to '...'
2. Click on '....'
3. See error

## Expected Behavior
What you expected to happen.

## Actual Behavior
What actually happened.

## Environment
- Environment: [development/staging/production]
- Ruby version: [e.g. 3.3.0]
- Rails version: [e.g. 7.1.5]
- Browser/Client: [if applicable]

## Screenshots/Logs
If applicable, add screenshots or error logs.

## Additional Context
Any other context about the problem.

## Possible Solution
If you have ideas on how to fix this.
```

### Feature Request Template

**File:** `.github/ISSUE_TEMPLATE/feature_request.md`

```markdown
---
name: Feature Request
about: Suggest a new feature
title: '[FEATURE] '
labels: enhancement, needs-discussion
assignees: ''
---

## Feature Description
A clear and concise description of the feature.

## Problem Statement
What problem does this solve?

## Proposed Solution
How should this feature work?

## Alternatives Considered
What other solutions have you thought about?

## User Stories
- As a [user type], I want [goal] so that [benefit]

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Technical Considerations
Any technical details, dependencies, or concerns.

## Priority
- [ ] High
- [ ] Medium
- [ ] Low

## Sprint
Which sprint should this be in? (if known)
```

### Task Template

**File:** `.github/ISSUE_TEMPLATE/task.md`

```markdown
---
name: Task
about: Create a development task
title: '[TASK] '
labels: task
assignees: ''
---

## Task Description
What needs to be done?

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Dependencies
- Depends on: #issue_number
- Blocks: #issue_number

## Estimated Effort
- [ ] Small (< 1 day)
- [ ] Medium (1-3 days)
- [ ] Large (> 3 days)

## Sprint
Sprint number (if assigned)

## Additional Notes
Any additional context or information.
```

### Template Config

**File:** `.github/ISSUE_TEMPLATE/config.yml`

```yaml
blank_issues_enabled: true
contact_links:
  - name: Documentation
    url: https://github.com/your-org/todo_app_server/wiki
    about: Check our documentation first
  - name: Discussions
    url: https://github.com/your-org/todo_app_server/discussions
    about: Ask questions and discuss ideas
```

---

## Labels and Organization

### Label Categories

**Type Labels:**
```
type: bug          (red)
type: feature      (green)
type: enhancement  (blue)
type: documentation (light blue)
type: refactor     (purple)
type: test         (yellow)
```

**Priority Labels:**
```
priority: critical (dark red)
priority: high     (orange)
priority: medium   (yellow)
priority: low      (light gray)
```

**Status Labels:**
```
status: needs-triage   (gray)
status: ready         (green)
status: blocked       (red)
status: in-progress   (blue)
status: needs-review  (orange)
```

**Area Labels:**
```
area: api          (pink)
area: database     (brown)
area: auth         (teal)
area: background-jobs (cyan)
area: testing      (lime)
area: ci-cd        (indigo)
```

**Sprint Labels:**
```
sprint-0  (light purple)
sprint-1  (light purple)
sprint-2  (light purple)
...
sprint-8  (light purple)
```

### Creating Labels

```bash
# Using GitHub CLI
gh label create "type: bug" --color "d73a4a" --description "Bug report"
gh label create "type: feature" --color "0e8a16" --description "New feature"
gh label create "priority: high" --color "ff9800" --description "High priority"

# Or create labels.yml file
```

**File:** `.github/labels.yml`

```yaml
- name: "type: bug"
  color: "d73a4a"
  description: "Bug report"

- name: "type: feature"
  color: "0e8a16"
  description: "New feature or request"

- name: "priority: critical"
  color: "b60205"
  description: "Critical priority - immediate attention"

- name: "priority: high"
  color: "ff9800"
  description: "High priority"

# ... add all labels
```

---

## Sprint Planning

### Creating Milestones (Sprints)

```bash
# Go to Issues → Milestones → New milestone

# Sprint 0
Title: Sprint 0 - Foundation & Planning
Description: Infrastructure setup, CI/CD, monitoring
Due date: 2025-11-18
```

### Sprint Structure

Each sprint milestone:
- **Duration:** 2 weeks
- **Planning:** Monday (Sprint start)
- **Review:** Friday (Sprint end)
- **Retrospective:** Friday (Sprint end)

### Sprint Workflow

**Week Before Sprint:**
1. Groom backlog
2. Estimate tasks
3. Prioritize features
4. Assign to milestone

**Sprint Start:**
1. Sprint planning meeting
2. Move issues to "Todo" column
3. Team members assign themselves
4. Create feature branches

**During Sprint:**
1. Daily standups (async via Slack/GitHub Discussions)
2. Move cards across board
3. Update issue status
4. Link PRs to issues

**Sprint End:**
1. Demo completed features
2. Close completed issues
3. Move incomplete items to next sprint
4. Sprint retrospective

---

## Reporting and Metrics

### Built-in GitHub Insights

**Insights Tab Provides:**
- Pulse (activity summary)
- Contributors
- Community standards
- Commits
- Code frequency
- Dependency graph
- Network

### Custom Reports

**Velocity Report:**
```
Track story points completed per sprint
- Small task: 1 point
- Medium task: 3 points
- Large task: 5 points
```

**Burn Down Chart:**
```
Track remaining work in sprint
- Use GitHub API to fetch issues
- Plot remaining vs. completed
```

### Metrics to Track

| Metric | Target | How to Measure |
|--------|--------|----------------|
| **Sprint Velocity** | 20-30 points | Sum of completed story points |
| **Completion Rate** | > 80% | Completed / Planned tasks |
| **Cycle Time** | < 3 days | Issue open → PR merged |
| **Lead Time** | < 5 days | Issue created → Deployed |
| **Bug Resolution** | < 24 hours | Critical bugs |
| **PR Review Time** | < 4 hours | PR ready → Approved |
| **Code Review Coverage** | 100% | All PRs reviewed |

### Generating Reports

**Using GitHub CLI:**
```bash
# List issues in current sprint
gh issue list --milestone "Sprint 1" --state all

# Export to CSV
gh issue list --milestone "Sprint 1" --json number,title,state,assignees --template '{{range .}}{{.number}},{{.title}},{{.state}}{{"\n"}}{{end}}' > sprint-1-report.csv
```

**Using GitHub API:**
```ruby
# script/generate_sprint_report.rb
require 'octokit'

client = Octokit::Client.new(access_token: ENV['GITHUB_TOKEN'])
repo = 'your-org/todo_app_server'
milestone_number = 1

issues = client.issues(repo, milestone: milestone_number, state: 'all')

puts "Sprint 1 Report"
puts "==============="
puts "Total Issues: #{issues.count}"
puts "Completed: #{issues.count { |i| i.state == 'closed' }}"
puts "In Progress: #{issues.count { |i| i.state == 'open' }}"
```

---

## Best Practices

### Issue Management

1. **Always link PRs to issues**
   ```
   Fixes #123
   Closes #456
   Related to #789
   ```

2. **Use descriptive titles**
   ```
   ✅ Add user authentication with JWT
   ❌ Auth stuff
   ```

3. **Add acceptance criteria**
   - Makes it clear when done
   - Helps with testing

4. **Estimate before starting**
   - Use story points or time
   - Helps with planning

5. **Update status regularly**
   - Move cards as work progresses
   - Add comments on blockers

### Pull Request Management

1. **Small, focused PRs**
   - Easier to review
   - Less likely to have bugs
   - Faster to merge

2. **Follow naming convention**
   ```
   feat: add user authentication
   fix: resolve login redirect issue
   refactor: simplify task controller
   ```

3. **Request reviews promptly**
   - Don't let PRs go stale
   - Assign specific reviewers

4. **Respond to feedback quickly**
   - Address comments
   - Re-request review after changes

### Sprint Management

1. **Don't overcommit**
   - Better to under-promise and over-deliver
   - Account for bugs and interruptions

2. **Groom backlog regularly**
   - Weekly backlog refinement
   - Keep top items detailed

3. **Track velocity**
   - Helps with future planning
   - Shows team capacity

4. **Celebrate wins**
   - Acknowledge completed sprints
   - Share demos with team

---

## GitHub Projects Quick Reference

### Creating a Project

```bash
# Via GitHub UI
Repository → Projects → New project → Board

# Via GitHub CLI
gh project create --title "Sprint 1" --body "Sprint 1 development"
```

### Adding Issues

```bash
# Drag and drop in UI
# Or use automation rules

# Via CLI
gh project item-add PROJECT_ID --content-id ISSUE_ID
```

### Moving Cards

```bash
# Drag and drop in UI

# Via API
curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/projects/columns/COLUMN_ID/cards/CARD_ID/moves \
  -d '{"position":"top", "column_id":NEW_COLUMN_ID}'
```

---

## Automation Examples

### Auto-assign to Project

**File:** `.github/workflows/auto-assign-project.yml`

```yaml
name: Auto Assign to Project

on:
  issues:
    types: [opened]
  pull_request:
    types: [opened]

jobs:
  add-to-project:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/add-to-project@v0.4.0
        with:
          project-url: https://github.com/orgs/your-org/projects/1
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

### Auto-label based on files

**File:** `.github/labeler.yml`

```yaml
'area: api':
  - app/controllers/**/*
  - app/serializers/**/*

'area: database':
  - db/**/*
  - app/models/**/*

'area: testing':
  - spec/**/*
  - test/**/*

'area: ci-cd':
  - .github/workflows/**/*
  - Dockerfile*
  - docker-compose*
```

---

## Next Steps

1. ✅ Project board documentation created
2. ⬜ Create GitHub Project board
3. ⬜ Set up issue templates
4. ⬜ Create labels
5. ⬜ Create Sprint 0 milestone
6. ⬜ Add all Sprint 0 tasks to backlog
7. ⬜ Set up project automation
8. ⬜ Train team on workflow
9. ⬜ Start Sprint 1 planning

---

**Document Version:** 1.0
**Last Updated:** 2025-11-04
**Maintained by:** Project Management Team
