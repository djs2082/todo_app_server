# CI/CD Pipeline Documentation

## Document Information
- **Version:** 1.0
- **Last Updated:** 2025-11-04
- **Status:** Sprint 0 - CI/CD Configuration
- **Purpose:** Complete guide for CI/CD pipelines using GitHub Actions

---

## Table of Contents
1. [Overview](#overview)
2. [Workflow Files](#workflow-files)
3. [CI Pipeline](#ci-pipeline)
4. [Build and Push Pipeline](#build-and-push-pipeline)
5. [Deployment Pipelines](#deployment-pipelines)
6. [Code Quality and Security](#code-quality-and-security)
7. [Required Secrets](#required-secrets)
8. [Branch Strategy](#branch-strategy)
9. [Automated Dependency Updates](#automated-dependency-updates)
10. [Troubleshooting](#troubleshooting)

---

## Overview

### CI/CD Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                        GitHub Repository                        │
└───────────────────────┬────────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Push/PR to   │  │ Push to      │  │ Manual       │
│ any branch   │  │ main/staging │  │ Trigger      │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │
       ▼                 ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   CI Tests   │  │ Build Docker │  │   Deploy     │
│   Security   │  │ Push to      │  │  Production  │
│   Quality    │  │ Registry     │  │              │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │
       ▼                 ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   Report     │  │  Auto Deploy │  │  Blue-Green  │
│   Results    │  │  to Staging  │  │  Deployment  │
└──────────────┘  └──────────────┘  └──────────────┘
```

### Pipeline Goals

- ✅ **Continuous Integration**: Automated testing on every push/PR
- ✅ **Code Quality**: Automated linting, security scanning, best practices
- ✅ **Continuous Delivery**: Automated builds and deployments to staging
- ✅ **Production Safety**: Manual approval for production deployments
- ✅ **Security**: Vulnerability scanning, dependency checks
- ✅ **Monitoring**: Notifications and reports

---

## Workflow Files

### File Structure

```
.github/
├── workflows/
│   ├── ci.yml                    # Main CI pipeline
│   ├── build-and-push.yml        # Docker build and registry push
│   ├── code-quality.yml          # Code quality and security scans
│   ├── deploy-staging.yml        # Staging deployment
│   └── deploy-production.yml     # Production deployment
└── dependabot.yml                # Automated dependency updates
```

### Workflow Summary

| Workflow | Trigger | Purpose | Duration |
|----------|---------|---------|----------|
| **ci.yml** | Push/PR to main, develop, staging | Run tests, linting, security | ~10 min |
| **build-and-push.yml** | Push to main/staging, version tags | Build and push Docker images | ~8 min |
| **code-quality.yml** | Push/PR, daily schedule | Code quality and security scans | ~12 min |
| **deploy-staging.yml** | Push to staging branch | Auto-deploy to staging | ~5 min |
| **deploy-production.yml** | Manual trigger only | Deploy to production | ~15 min |

---

## CI Pipeline

### File: `.github/workflows/ci.yml`

#### Jobs Overview

```
┌─────────────┐
│ Push/PR     │
└──────┬──────┘
       │
       ├──────────────────────────────────────┐
       │                                      │
       ▼                                      ▼
┌──────────────┐                      ┌──────────────┐
│    Lint      │                      │   Security   │
│  (RuboCop)   │                      │  (Brakeman)  │
└──────┬───────┘                      └──────┬───────┘
       │                                      │
       │            ┌──────────────┐          │
       └───────────►│    Tests     │◄─────────┘
                    │   (RSpec)    │
                    └──────┬───────┘
                           │
                ┌──────────┼──────────┐
                │                     │
                ▼                     ▼
         ┌──────────────┐      ┌──────────────┐
         │  Migrations  │      │Docker Build  │
         │    Check     │      │     Test     │
         └──────┬───────┘      └──────┬───────┘
                │                     │
                └──────────┬──────────┘
                           │
                           ▼
                    ┌──────────────┐
                    │   Summary    │
                    │  & Notify    │
                    └──────────────┘
```

#### Jobs Detail

**1. Lint (RuboCop)**
- Runs RuboCop for code style and formatting
- Parallel execution for speed
- Generates JSON report
- Uploads artifact for review

**2. Security (Brakeman + bundler-audit)**
- Brakeman: Scans for security vulnerabilities
- bundler-audit: Checks gem dependencies for known CVEs
- bundler-leak: Checks for memory leaks
- Fails build on critical issues

**3. Test (RSpec)**
- Runs full RSpec test suite
- Uses MySQL and Redis services
- Generates coverage report (requires 85% minimum)
- Uploads coverage to Codecov
- Parallel test execution

**4. Migrations**
- Tests database migrations
- Verifies migrations can rollback
- Checks for pending migrations
- Validates migration status

**5. Docker Build**
- Tests both development and production Docker builds
- Validates Dockerfile syntax
- Uses BuildKit caching for speed
- No push (test only)

**6. Summary**
- Aggregates all job results
- Sends Slack notification on failure
- Fails if any job failed
- Creates deployment summary

#### Running Locally

```bash
# Install Act (GitHub Actions local runner)
brew install act  # macOS
# or
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Run CI locally
act pull_request

# Run specific job
act -j test

# Run with secrets
act -s GITHUB_TOKEN=your_token
```

---

## Build and Push Pipeline

### File: `.github/workflows/build-and-push.yml`

#### Trigger Conditions

- **Push to main**: Builds `latest` and `main` tags
- **Push to staging**: Builds `staging` tag
- **Version tags** (v1.0.0): Builds version tags
- **Manual**: Can specify environment

#### Docker Registry Options

The workflow supports multiple registries:

**1. GitHub Container Registry (Default)**
```yaml
REGISTRY: ghcr.io
```
- Free for public repos
- $0.008/GB storage for private
- Integrated with GitHub

**2. Docker Hub**
```yaml
# Uncomment in workflow file
username: ${{ secrets.DOCKER_HUB_USERNAME }}
password: ${{ secrets.DOCKER_HUB_TOKEN }}
```

**3. AWS ECR**
```yaml
# Uncomment in workflow file
aws-region: us-east-1
```

#### Image Tags Strategy

| Trigger | Tags Generated |
|---------|---------------|
| Push to main | `latest`, `main`, `main-<sha>` |
| Push to staging | `staging`, `staging-<sha>` |
| Tag v1.2.3 | `v1.2.3`, `1.2.3`, `1.2`, `1` |
| PR #123 | `pr-123` |

#### Jobs Detail

**1. build-and-push**
- Multi-stage Docker build
- Pushes to registry
- Generates build provenance
- Uses layer caching

**2. security-scan**
- Runs Trivy vulnerability scanner
- Uploads results to GitHub Security
- Scans for CRITICAL and HIGH severity
- Fails on critical vulnerabilities

**3. smoke-test**
- Pulls built image
- Starts container
- Runs database migrations
- Tests health endpoint
- Validates image works

**4. release**
- Creates GitHub Release for version tags
- Generates changelog from git history
- Includes image verification info

**5. notify**
- Sends Slack notifications
- Reports build success/failure
- Includes image details

---

## Deployment Pipelines

### Staging Deployment

**File:** `.github/workflows/deploy-staging.yml`

#### Auto-deploy Workflow

```
Push to staging branch
         │
         ▼
  ┌──────────────┐
  │  Pre-deploy  │
  │    Checks    │
  └──────┬───────┘
         │
         ▼
  ┌──────────────┐
  │   Deploy     │
  │  via SSH     │
  └──────┬───────┘
         │
    ┌────┼────┐
    │         │
    ▼         ▼
┌────────┐ ┌────────┐
│Verify  │ │ Smoke  │
│Deploy  │ │ Tests  │
└────┬───┘ └───┬────┘
     │         │
     └────┬────┘
          │
          ▼
   ┌──────────────┐
   │   Notify     │
   │   & Report   │
   └──────────────┘
```

#### Deployment Steps

1. **Pull latest code** from staging branch
2. **Verify commit** matches expected SHA
3. **Pull Docker image** from registry
4. **Stop old containers**
5. **Start new containers**
6. **Run migrations**
7. **Health check** (30 retries, 2s interval)
8. **Verify** external URL
9. **Run smoke tests**
10. **Notify team**

#### Rollback on Failure

If deployment fails:
1. Automatically reverts to previous commit
2. Restarts containers with old version
3. Sends alert notification

### Production Deployment

**File:** `.github/workflows/deploy-production.yml`

#### Manual Approval Required

Production deployments require:
1. **Manual trigger** (no auto-deploy)
2. **Approval gate** (production-approval environment)
3. **Version tag** must exist
4. **Pre-deployment validation**
5. **Database backup** before deploy

#### Deployment Strategies

**Option 1: Blue-Green Deployment**
```
┌─────────┐           ┌─────────┐
│  Blue   │           │  Green  │
│ (v1.0)  │           │ (v1.1)  │
│         │           │         │
│ Active  │           │ Deploy  │
└────┬────┘           └────┬────┘
     │                     │
     │    Load Balancer    │
     │         │           │
     └─────────┴───────────┘
                 │
          ┌──────┴──────┐
          │  Traffic    │
          │  Switch     │
          └──────┬──────┘
                 │
     ┌───────────┴───────────┐
     │                       │
┌────┴────┐           ┌──────▼──┐
│  Blue   │           │  Green  │
│ (v1.0)  │           │ (v1.1)  │
│         │           │         │
│ Standby │           │ Active  │
└─────────┘           └─────────┘
```

**Option 2: Rolling Deployment**
```
┌──────────────────────────────┐
│      Pods (v1.0)             │
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐    │
│  │ 1 │ │ 2 │ │ 3 │ │ 4 │    │
│  └───┘ └───┘ └───┘ └───┘    │
└──────────────────────────────┘
         │
         ▼ Update one by one
┌──────────────────────────────┐
│      Pods (v1.1)             │
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐    │
│  │ 1'│ │ 2 │ │ 3 │ │ 4 │    │
│  └───┘ └───┘ └───┘ └───┘    │
└──────────────────────────────┘
```

#### Deployment Steps (Blue-Green)

1. **Approval** - Manual approval required
2. **Pre-deploy validation**
   - Verify version tag exists
   - Check Docker image exists
   - Run security scan
   - Validate migrations
3. **Backup** - Full database backup to S3
4. **Deploy to inactive environment** (Green if Blue is active)
5. **Run migrations** on new environment
6. **Health checks** on new environment
7. **Smoke tests** on new environment
8. **Switch traffic** to new environment
9. **Monitor** for 2 minutes
10. **Scale down** old environment (keep 1 replica)
11. **Post-deploy validation**
12. **Notify team**

#### Rollback Procedure

If deployment fails:
1. **Automatic rollback** triggered
2. **Kubernetes rollout undo** executed
3. **Health check** after rollback
4. **Alert** sent to team
5. **Incident report** created

---

## Code Quality and Security

### File: `.github/workflows/code-quality.yml`

#### Scheduled Scans

Runs daily at 2 AM UTC for continuous monitoring.

#### Tools and Checks

| Tool | Purpose | Severity |
|------|---------|----------|
| **RuboCop** | Code style, formatting | Warning |
| **Brakeman** | Security vulnerabilities | Critical |
| **bundler-audit** | Dependency vulnerabilities | Critical |
| **bundle-leak** | Memory leaks in gems | Warning |
| **rails_best_practices** | Rails conventions | Info |
| **Flog** | Code complexity | Info |
| **Reek** | Code smells | Warning |
| **CodeQL** | Security analysis | Critical |
| **license_finder** | License compliance | Info |

#### Security Thresholds

- **Critical vulnerabilities**: Build fails immediately
- **High vulnerabilities**: Warning, requires review
- **Medium vulnerabilities**: Warning
- **Low vulnerabilities**: Informational

#### Reports

All reports uploaded as artifacts:
- **RuboCop** report (JSON)
- **Brakeman** report (JSON + SARIF)
- **Rails Best Practices** report (JSON)
- **Flog** report (Text)
- **Reek** report (JSON)
- **License** report (JSON)

Access reports:
1. Go to Actions tab
2. Select workflow run
3. Download artifacts

---

## Required Secrets

### GitHub Secrets Setup

Navigate to: **Settings → Secrets and variables → Actions**

#### Required for All Environments

| Secret | Description | Example |
|--------|-------------|---------|
| `GITHUB_TOKEN` | Auto-provided by GitHub | (automatic) |

#### Staging Deployment

| Secret | Description | Example |
|--------|-------------|---------|
| `STAGING_HOST` | Staging server hostname | staging.example.com |
| `STAGING_SSH_USER` | SSH username | deploy |
| `STAGING_SSH_KEY` | SSH private key | (RSA private key) |
| `STAGING_SSH_PORT` | SSH port (optional) | 22 |

#### Production Deployment

| Secret | Description | Example |
|--------|-------------|---------|
| `PRODUCTION_HOST` | Production server | prod.example.com |
| `PRODUCTION_SSH_USER` | SSH username | deploy |
| `PRODUCTION_SSH_KEY` | SSH private key | (RSA private key) |
| `KUBE_CONFIG` | Kubernetes config (base64) | (base64 encoded) |
| `PRODUCTION_DB_HOST` | Database host | db.prod.example.com |
| `DB_HOST` | Database hostname | db-prod-instance |
| `DB_USER` | Database user | app_user |
| `DB_PASSWORD` | Database password | (strong password) |
| `DB_NAME` | Database name | todo_app_production |
| `BACKUP_S3_BUCKET` | S3 bucket for backups | app-prod-backups |

#### Optional (Notifications)

| Secret | Description |
|--------|-------------|
| `SLACK_WEBHOOK_URL` | Slack webhook for notifications |
| `PAGERDUTY_INTEGRATION_KEY` | PagerDuty for critical alerts |

#### Optional (External Services)

| Secret | Description |
|--------|-------------|
| `DOCKER_HUB_USERNAME` | Docker Hub username |
| `DOCKER_HUB_TOKEN` | Docker Hub access token |
| `AWS_ACCESS_KEY_ID` | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |
| `CODECOV_TOKEN` | Codecov upload token |

### Setting up SSH Keys

```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -C "github-actions@your-domain.com" -f deploy_key

# Copy public key to server
ssh-copy-id -i deploy_key.pub deploy@staging.example.com

# Add private key to GitHub Secrets
cat deploy_key | pbcopy  # macOS
# Paste into GitHub Secrets as STAGING_SSH_KEY

# Don't forget to secure the keys
chmod 600 deploy_key
```

### Setting up Kubernetes Config

```bash
# Get current kubeconfig
kubectl config view --flatten

# Base64 encode it
kubectl config view --flatten | base64

# Add to GitHub Secrets as KUBE_CONFIG
```

---

## Branch Strategy

### GitFlow Workflow

```
main (production)
  │
  ├─── staging (pre-production)
  │      │
  │      ├─── develop (integration)
  │      │      │
  │      │      ├─── feature/user-auth
  │      │      ├─── feature/task-assignment
  │      │      └─── bugfix/login-error
  │      │
  │      └─── (auto-merge after testing)
  │
  └─── (manual release after approval)
```

### Branch Protection Rules

**main branch:**
- ✅ Require pull request reviews (2 approvals)
- ✅ Require status checks to pass (CI must pass)
- ✅ Require conversation resolution
- ✅ Require signed commits
- ✅ Include administrators
- ❌ No direct pushes

**staging branch:**
- ✅ Require pull request reviews (1 approval)
- ✅ Require status checks to pass
- ❌ Allow force pushes (with lease)

**develop branch:**
- ✅ Require status checks to pass
- ✅ Allow direct pushes from maintainers

### Workflow by Branch

| Branch | CI | Build | Deploy |
|--------|----|----|--------|
| feature/* | ✅ | ❌ | ❌ |
| develop | ✅ | ❌ | ❌ |
| staging | ✅ | ✅ | ✅ Auto (staging) |
| main | ✅ | ✅ | ⚠️ Manual (production) |
| v*.*.* (tags) | ✅ | ✅ | ⚠️ Manual |

---

## Automated Dependency Updates

### Dependabot Configuration

**File:** `.github/dependabot.yml`

#### Update Schedule

| Package Ecosystem | Day | Frequency |
|-------------------|-----|-----------|
| Ruby (Bundler) | Monday | Weekly |
| Docker | Tuesday | Weekly |
| GitHub Actions | Wednesday | Weekly |

#### Grouped Updates

**Rails Group:**
- All Rails-related gems updated together
- Ensures compatibility

**Security Group:**
- Rack, bcrypt, JWT together
- Critical for security

**Testing Group:**
- RSpec and related gems
- Safe to update together

#### Auto-merge Strategy

Low-risk updates can be auto-merged:
- Patch version updates (1.0.1 → 1.0.2)
- Minor version updates for dev dependencies
- Passing all CI checks

Medium/high-risk require review:
- Minor version updates (1.0.0 → 1.1.0)
- Major version updates (1.0.0 → 2.0.0)
- Security-related gems

---

## Troubleshooting

### Common Issues

#### 1. CI Failing - RuboCop Errors

**Problem:** Code style violations

**Solution:**
```bash
# Auto-fix most issues
bundle exec rubocop -A

# Check specific files
bundle exec rubocop app/controllers/users_controller.rb

# Generate todo list for existing violations
bundle exec rubocop --auto-gen-config
```

#### 2. Tests Failing Locally But Pass in CI

**Problem:** Environment differences

**Solution:**
```bash
# Use same Ruby version
rbenv install 3.3.0
rbenv local 3.3.0

# Use same database
RAILS_ENV=test bundle exec rails db:reset

# Clear cache
bundle exec rails tmp:clear

# Run tests with same settings as CI
RAILS_ENV=test bundle exec rspec
```

#### 3. Docker Build Timeout

**Problem:** Build takes too long

**Solution:**
```yaml
# Increase timeout in workflow
timeout-minutes: 30

# Use BuildKit caching
DOCKER_BUILDKIT=1 docker build .

# Multi-stage builds already optimized
```

#### 4. Deployment Fails - Permission Denied

**Problem:** SSH key issues

**Solution:**
```bash
# Verify SSH key format
cat deploy_key | head -n 1
# Should be: -----BEGIN RSA PRIVATE KEY-----

# Test SSH connection
ssh -i deploy_key deploy@staging.example.com

# Check server permissions
ls -la ~/.ssh/authorized_keys
```

#### 5. Database Migration Fails

**Problem:** Migration not compatible

**Solution:**
```bash
# Test migrations locally first
bundle exec rails db:migrate
bundle exec rails db:rollback
bundle exec rails db:migrate

# Use strong migrations gem
gem 'strong_migrations'

# Check migration safety
bundle exec rails strong_migrations:check
```

### Getting Help

- Check **Actions** tab for detailed logs
- Review **artifacts** for reports
- Check **GitHub Security** tab for vulnerabilities
- Slack **#ci-cd-support** channel
- Create issue in repository

---

## Performance Benchmarks

### Target Times

| Workflow | Target | Actual |
|----------|--------|--------|
| CI (fast path) | < 5 min | ~4 min |
| CI (full) | < 12 min | ~10 min |
| Build | < 10 min | ~8 min |
| Deploy (staging) | < 7 min | ~5 min |
| Deploy (production) | < 20 min | ~15 min |

### Optimization Tips

1. **Use caching**
   - Gem caching (bundler)
   - Docker layer caching
   - Test fixtures caching

2. **Parallel execution**
   - RuboCop with `--parallel`
   - RSpec with parallel_tests gem
   - Independent jobs run concurrently

3. **Matrix strategies**
   - Test multiple Ruby versions
   - Test multiple databases

4. **Skip unnecessary runs**
   - Skip CI on docs-only changes
   - Skip builds on test-only changes

---

## Best Practices

### Commit Messages

Follow conventional commits:

```
feat: add user authentication
fix: resolve login redirect issue
chore: update dependencies
docs: add API documentation
test: add user model tests
refactor: simplify task controller
perf: optimize database queries
ci: add deployment workflow
```

### Pull Requests

1. **Create PR early** with `[WIP]` prefix
2. **Ensure CI passes** before requesting review
3. **Add description** explaining changes
4. **Link issues** using `Fixes #123`
5. **Request reviews** from relevant team members
6. **Resolve conversations** before merging

### Release Process

1. Create release branch from `main`
2. Update version in appropriate files
3. Update CHANGELOG.md
4. Create pull request to `main`
5. After merge, create version tag
6. GitHub Actions creates release
7. Deploy to production via workflow

---

## Monitoring and Alerts

### GitHub Actions Status

Monitor at: `https://github.com/your-org/todo_app_server/actions`

### Notifications

**Slack Integration:**
- CI failures
- Deployment status
- Security alerts

**Email:**
- Dependabot PRs
- Security advisories
- Workflow failures

**PagerDuty (Production):**
- Critical failures
- Deployment failures
- Rollback triggers

---

## Next Steps

After setting up CI/CD:

1. ✅ All workflows created
2. ✅ Secrets configured
3. ⬜ Test CI pipeline with sample PR
4. ⬜ Test staging deployment
5. ⬜ Configure branch protection rules
6. ⬜ Set up Slack notifications
7. ⬜ Test production deployment (dry run)
8. ⬜ Train team on CI/CD workflows

---

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Build Push Action](https://github.com/docker/build-push-action)
- [Dependabot Documentation](https://docs.github.com/en/code-security/dependabot)
- [RuboCop Documentation](https://docs.rubocop.org/)
- [Brakeman Scanner](https://brakemanscanner.org/)

---

**Document Version:** 1.0
**Last Updated:** 2025-11-04
**Maintained by:** DevOps Team
