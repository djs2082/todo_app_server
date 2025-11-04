# Environment Setup Guide

## Document Information
- **Version:** 1.0
- **Last Updated:** 2025-11-04
- **Status:** Sprint 0 - Infrastructure Setup
- **Purpose:** Complete guide for setting up development, staging, and production environments

---

## Table of Contents
1. [Overview](#overview)
2. [Development Environment](#development-environment)
3. [Staging Environment](#staging-environment)
4. [Production Environment](#production-environment)
5. [Environment Variables Reference](#environment-variables-reference)
6. [Docker Configuration](#docker-configuration)
7. [Deployment Workflows](#deployment-workflows)
8. [Monitoring & Health Checks](#monitoring--health-checks)
9. [Troubleshooting](#troubleshooting)

---

## Overview

### Environment Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     ENVIRONMENTS                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Development          Staging            Production         │
│  ───────────          ───────            ──────────         │
│  Local machine        Cloud VM           Kubernetes/ECS     │
│  Docker Compose       Docker Compose     Container Orch.    │
│  SQLite (test)        MySQL 8.0          MySQL RDS          │
│  MySQL 8.0 (dev)      Redis 7            Redis ElastiCache  │
│  Redis 7              AWS S3             AWS S3 + CloudFront│
│  Letter Opener        SMTP               SMTP (Production)  │
│  Debug enabled        Monitoring         Full monitoring    │
│                       Sentry              Sentry + New Relic│
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Purpose of Each Environment

| Environment | Purpose | Infrastructure | Data | Access |
|-------------|---------|----------------|------|--------|
| **Development** | Local development and testing | Docker Compose on localhost | Sample/seed data | All developers |
| **Staging** | Pre-production testing and QA | Cloud VM or container service | Anonymized prod-like data | Dev team + QA |
| **Production** | Live application serving users | Kubernetes/ECS/managed services | Real user data | DevOps only |

---

## Development Environment

### Prerequisites

- **Docker Desktop** (version 20.10+)
- **Docker Compose** (version 2.0+)
- **Git**
- **Ruby** 3.3.0 (if running locally without Docker)
- **MySQL** 8.0 (if running locally)
- **Redis** 7.0 (if running locally)

### Quick Start with Docker

```bash
# 1. Clone the repository
git clone https://github.com/your-org/todo_app_server.git
cd todo_app_server

# 2. Copy environment file
cp .env.development.example .env.development

# 3. Edit environment variables (optional)
nano .env.development

# 4. Start all services
docker-compose -f docker-compose.development.yml up

# 5. Open in browser
# API: http://localhost:3000
# Adminer (DB UI): http://localhost:8080
# MailCatcher: http://localhost:1080
# Redis Commander: http://localhost:8081
```

### Development Environment Services

| Service | Port | URL | Credentials |
|---------|------|-----|-------------|
| Rails API | 3000 | http://localhost:3000 | - |
| MySQL | 3306 | localhost:3306 | root/password |
| Redis | 6379 | localhost:6379 | - |
| Adminer | 8080 | http://localhost:8080 | root/password |
| MailCatcher | 1080 | http://localhost:1080 | - |
| Redis Commander | 8081 | http://localhost:8081 | - |

### Running Locally (Without Docker)

```bash
# 1. Install dependencies
bundle install

# 2. Set up database
cp .env.development.example .env.development
# Edit .env.development with local database credentials
rails db:create db:migrate

# 3. Seed sample data
rails db:seed

# 4. Start Redis (in separate terminal)
redis-server

# 5. Start Resque worker (in separate terminal)
QUEUE=* bundle exec rake resque:work

# 6. Start Resque scheduler (in separate terminal)
bundle exec rake resque:scheduler

# 7. Start Rails server
bundle exec rails server

# 8. Visit http://localhost:3000
```

### Development Workflow

```bash
# Create a new branch
git checkout -b feature/your-feature-name

# Make changes to code

# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop

# Run security scan
bundle exec brakeman

# Check for N+1 queries (Bullet gem)
# Warnings will appear in Rails logs and browser console

# Commit changes
git add .
git commit -m "feat: your feature description"

# Push to remote
git push origin feature/your-feature-name

# Create pull request on GitHub
```

### Development Tools

#### Database Management
```bash
# Access MySQL console via Docker
docker-compose -f docker-compose.development.yml exec db mysql -u root -p

# Access MySQL console locally
mysql -u root -p todo_app_development

# Run migrations
docker-compose -f docker-compose.development.yml exec app bundle exec rails db:migrate

# Rollback migration
docker-compose -f docker-compose.development.yml exec app bundle exec rails db:rollback

# Reset database
docker-compose -f docker-compose.development.yml exec app bundle exec rails db:reset
```

#### Debugging
```bash
# View Rails logs
docker-compose -f docker-compose.development.yml logs -f app

# Access Rails console
docker-compose -f docker-compose.development.yml exec app bundle exec rails console

# Access container shell
docker-compose -f docker-compose.development.yml exec app /bin/bash
```

#### Testing
```bash
# Run all tests
docker-compose -f docker-compose.development.yml exec app bundle exec rspec

# Run specific test file
docker-compose -f docker-compose.development.yml exec app bundle exec rspec spec/models/user_spec.rb

# Run with coverage
docker-compose -f docker-compose.development.yml exec app bundle exec rspec --coverage

# View coverage report
open coverage/index.html
```

---

## Staging Environment

### Infrastructure Setup

Staging environment is deployed on cloud infrastructure (AWS, DigitalOcean, etc.) using Docker Compose for simplicity.

### Prerequisites

- Cloud VM (2 vCPU, 4GB RAM minimum)
- Docker & Docker Compose installed
- Domain name configured (e.g., staging-api.your-domain.com)
- SSL certificate (Let's Encrypt)
- Managed database (optional but recommended)
- Managed Redis (optional but recommended)

### Deployment Steps

```bash
# 1. SSH into staging server
ssh user@staging-server.your-domain.com

# 2. Clone repository
git clone https://github.com/your-org/todo_app_server.git
cd todo_app_server

# 3. Checkout staging branch (if different from main)
git checkout staging

# 4. Copy and configure environment file
cp .env.staging.example .env.staging
nano .env.staging

# IMPORTANT: Set all CHANGEME values with real credentials!

# 5. Build and start services
docker-compose -f docker-compose.staging.yml build
docker-compose -f docker-compose.staging.yml up -d

# 6. Run database migrations
docker-compose -f docker-compose.staging.yml exec app bundle exec rails db:migrate

# 7. Check health
curl http://localhost:3000/health

# 8. View logs
docker-compose -f docker-compose.staging.yml logs -f
```

### Staging Environment Services

| Service | Internal Port | External Access |
|---------|--------------|-----------------|
| Rails API | 3000 | https://staging-api.your-domain.com |
| MySQL | 3306 | Internal only |
| Redis | 6379 | Internal only |
| Nginx | 80, 443 | Public |
| Prometheus | 9090 | https://prometheus-staging.your-domain.com |
| Grafana | 3001 | https://monitoring-staging.your-domain.com |

### Continuous Deployment (GitHub Actions)

```yaml
# .github/workflows/deploy-staging.yml
name: Deploy to Staging

on:
  push:
    branches: [staging]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Deploy to staging server
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.STAGING_HOST }}
          username: ${{ secrets.STAGING_USER }}
          key: ${{ secrets.STAGING_SSH_KEY }}
          script: |
            cd /home/deploy/todo_app_server
            git pull origin staging
            docker-compose -f docker-compose.staging.yml build
            docker-compose -f docker-compose.staging.yml up -d
            docker-compose -f docker-compose.staging.yml exec -T app bundle exec rails db:migrate
```

### Monitoring Staging

```bash
# View application logs
docker-compose -f docker-compose.staging.yml logs -f app

# View Sidekiq logs
docker-compose -f docker-compose.staging.yml logs -f sidekiq

# View database logs
docker-compose -f docker-compose.staging.yml logs -f db

# Check resource usage
docker stats

# Access Grafana dashboards
# Visit https://monitoring-staging.your-domain.com
```

---

## Production Environment

### Infrastructure Architecture

Production should use managed container orchestration (Kubernetes, AWS ECS) rather than Docker Compose.

**Recommended Production Stack:**
- **Compute:** AWS ECS/EKS, DigitalOcean Kubernetes, or Google GKE
- **Database:** AWS RDS MySQL, DigitalOcean Managed MySQL
- **Cache:** AWS ElastiCache Redis, Redis Cloud
- **Storage:** AWS S3, DigitalOcean Spaces
- **CDN:** CloudFront, Cloudflare
- **Load Balancer:** AWS ALB, Nginx Ingress
- **Monitoring:** New Relic, Datadog, Prometheus + Grafana
- **Logging:** AWS CloudWatch, ELK Stack, Loki
- **Error Tracking:** Sentry

### Kubernetes Deployment

For Kubernetes deployment, we'll create separate manifests in `k8s/` directory:

```
k8s/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── configmap.yaml
│   └── secret.yaml
├── overlays/
│   ├── staging/
│   │   └── kustomization.yaml
│   └── production/
│       └── kustomization.yaml
└── README.md
```

### Production Deployment Process

```bash
# 1. Build and push Docker image
docker build -t your-registry.com/todo-app:v1.0.0 -f Dockerfile.new --target production .
docker push your-registry.com/todo-app:v1.0.0

# 2. Apply Kubernetes manifests
kubectl apply -k k8s/overlays/production

# 3. Run database migrations
kubectl exec -it deployment/todo-app -- bundle exec rails db:migrate

# 4. Check rollout status
kubectl rollout status deployment/todo-app

# 5. Verify pods are running
kubectl get pods -l app=todo-app

# 6. Check logs
kubectl logs -f deployment/todo-app

# 7. Test health endpoint
kubectl port-forward deployment/todo-app 3000:3000
curl http://localhost:3000/health
```

### Blue-Green Deployment

```bash
# 1. Deploy new version (green)
kubectl apply -f k8s/production/deployment-green.yaml

# 2. Wait for green deployment to be ready
kubectl wait --for=condition=available --timeout=300s deployment/todo-app-green

# 3. Run smoke tests on green deployment
./scripts/smoke-test.sh green

# 4. Switch traffic to green
kubectl patch service todo-app -p '{"spec":{"selector":{"version":"green"}}}'

# 5. Monitor for issues
# If issues found, rollback:
kubectl patch service todo-app -p '{"spec":{"selector":{"version":"blue"}}}'

# 6. If successful, delete blue deployment
kubectl delete deployment todo-app-blue
```

### Auto-Scaling Configuration

```yaml
# k8s/production/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: todo-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: todo-app
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

---

## Environment Variables Reference

### Critical Variables (All Environments)

| Variable | Description | Example | Required |
|----------|-------------|---------|----------|
| `RAILS_ENV` | Rails environment | development/staging/production | ✅ |
| `SECRET_KEY_BASE` | Rails secret key | Generate with `rails secret` | ✅ |
| `DATABASE_HOST` | Database hostname | localhost, db, or RDS endpoint | ✅ |
| `DATABASE_USERNAME` | Database user | root, admin | ✅ |
| `DATABASE_PASSWORD` | Database password | Strong password | ✅ |
| `DATABASE_NAME` | Database name | todo_app_production | ✅ |
| `REDIS_URL` | Redis connection URL | redis://localhost:6379/0 | ✅ |

### Security Variables (Production)

| Variable | Description | Example | Required |
|----------|-------------|---------|----------|
| `JWT_SECRET_KEY` | JWT signing secret | Random 64-char string | ✅ |
| `RAILS_MASTER_KEY` | Rails credentials key | From config/master.key | ✅ |
| `FORCE_SSL` | Force HTTPS | true | ✅ |
| `HSTS_ENABLED` | HTTP Strict Transport Security | true | ✅ |

### Third-Party Services

| Variable | Description | Required |
|----------|-------------|----------|
| `OPENAI_API_KEY` | OpenAI API key for AI features | For AI features |
| `SENTRY_DSN` | Sentry error tracking | Production |
| `NEW_RELIC_LICENSE_KEY` | New Relic APM | Production |
| `STRIPE_SECRET_KEY` | Stripe payment processing | If payments enabled |
| `AWS_ACCESS_KEY_ID` | AWS S3 access | If using S3 |
| `AWS_SECRET_ACCESS_KEY` | AWS S3 secret | If using S3 |

---

## Docker Configuration

### Dockerfile Stages

The new multi-stage Dockerfile (`Dockerfile.new`) has the following stages:

1. **base** - Common base layer with system dependencies
2. **dependencies** - Gem installation layer (cached)
3. **development** - Development environment with debug tools
4. **build** - Production build with asset compilation
5. **production** - Minimal production runtime

### Building for Different Environments

```bash
# Development
docker build -t todo-app:dev --target development .

# Production
docker build -t todo-app:prod --target production .

# With BuildKit (faster)
DOCKER_BUILDKIT=1 docker build -t todo-app:prod --target production .
```

### Docker Compose Commands Reference

```bash
# Start services
docker-compose -f docker-compose.{env}.yml up

# Start in background
docker-compose -f docker-compose.{env}.yml up -d

# Stop services
docker-compose -f docker-compose.{env}.yml down

# Stop and remove volumes (CAUTION: deletes data)
docker-compose -f docker-compose.{env}.yml down -v

# Rebuild specific service
docker-compose -f docker-compose.{env}.yml build app

# View logs
docker-compose -f docker-compose.{env}.yml logs -f

# Execute command in container
docker-compose -f docker-compose.{env}.yml exec app bundle exec rails console

# Scale service (e.g., more workers)
docker-compose -f docker-compose.{env}.yml up -d --scale sidekiq=5
```

---

## Deployment Workflows

### CI/CD Pipeline

```
┌──────────────┐
│  Code Push   │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  Run Tests   │ ◄─── RSpec, RuboCop, Brakeman
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Build Docker │ ◄─── Multi-stage build
│    Image     │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Push to      │ ◄─── Docker Registry
│ Registry     │
└──────┬───────┘
       │
       ├─────────────────┬─────────────────┐
       ▼                 ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   Deploy     │  │   Deploy     │  │   Deploy     │
│ Development  │  │   Staging    │  │  Production  │
└──────────────┘  └──────────────┘  └──────────────┘
                         │                 │
                         ▼                 ▼
                  ┌──────────────┐  ┌──────────────┐
                  │   Run E2E    │  │   Blue-Green │
                  │    Tests     │  │  Deployment  │
                  └──────────────┘  └──────────────┘
```

### GitHub Actions Example

See `.github/workflows/` directory for complete CI/CD workflows:
- `ci.yml` - Run tests and linting
- `build.yml` - Build and push Docker images
- `deploy-staging.yml` - Deploy to staging
- `deploy-production.yml` - Deploy to production

---

## Monitoring & Health Checks

### Health Check Endpoints

| Endpoint | Purpose | Response |
|----------|---------|----------|
| `/health` | Liveness probe | `{"status": "ok"}` |
| `/ready` | Readiness probe | `{"status": "ready", "checks": {...}}` |
| `/live` | Kubernetes liveness | `{"alive": true}` |

### Health Check Implementation

```ruby
# config/routes.rb
get '/health', to: 'health#index'
get '/ready', to: 'health#ready'
get '/live', to: 'health#live'

# app/controllers/health_controller.rb
class HealthController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    render json: { status: 'ok' }, status: :ok
  end

  def ready
    checks = {
      database: database_check,
      redis: redis_check,
      migrations: migration_check
    }

    all_ok = checks.values.all? { |v| v == 'ok' }
    status = all_ok ? :ok : :service_unavailable

    render json: { status: all_ok ? 'ready' : 'not_ready', checks: checks }, status: status
  end

  def live
    render json: { alive: true }, status: :ok
  end

  private

  def database_check
    ActiveRecord::Base.connection.execute('SELECT 1')
    'ok'
  rescue => e
    "error: #{e.message}"
  end

  def redis_check
    Redis.new(url: ENV['REDIS_URL']).ping
    'ok'
  rescue => e
    "error: #{e.message}"
  end

  def migration_check
    ActiveRecord::Migration.check_pending!
    'ok'
  rescue ActiveRecord::PendingMigrationError
    'pending migrations'
  end
end
```

### Monitoring Tools

**Development:**
- Rails logs
- Bullet gem for N+1 queries
- Rack Mini Profiler

**Staging:**
- Prometheus + Grafana
- Sentry for errors
- Application logs

**Production:**
- New Relic or Datadog APM
- Sentry for error tracking
- Prometheus + Grafana
- ELK Stack or CloudWatch for logs
- PagerDuty for alerting

---

## Troubleshooting

### Common Issues

#### Docker Compose won't start

```bash
# Check Docker is running
docker info

# Check docker-compose file syntax
docker-compose -f docker-compose.development.yml config

# Remove old containers and volumes
docker-compose -f docker-compose.development.yml down -v
docker system prune -a

# Rebuild from scratch
docker-compose -f docker-compose.development.yml build --no-cache
docker-compose -f docker-compose.development.yml up
```

#### Database connection errors

```bash
# Check database is running
docker-compose -f docker-compose.development.yml ps db

# Check database logs
docker-compose -f docker-compose.development.yml logs db

# Access MySQL console to verify
docker-compose -f docker-compose.development.yml exec db mysql -u root -p

# Verify DATABASE_HOST in .env file
# For Docker: DATABASE_HOST=db
# For local: DATABASE_HOST=localhost
```

#### Redis connection errors

```bash
# Check Redis is running
docker-compose -f docker-compose.development.yml ps redis

# Test Redis connection
docker-compose -f docker-compose.development.yml exec redis redis-cli ping

# Check REDIS_URL format
# Correct: redis://redis:6379/0 (for Docker)
# Correct: redis://localhost:6379/0 (for local)
```

#### Permission denied errors

```bash
# Fix file permissions
chmod +x bin/*
chmod +x scripts/*

# If running as non-root in Docker
docker-compose -f docker-compose.development.yml exec --user root app chown -R app:app /app
```

#### Out of memory errors

```bash
# Increase Docker memory limit
# Docker Desktop > Settings > Resources > Memory > 4GB+

# Check current usage
docker stats

# Clean up unused resources
docker system prune -a
```

### Getting Help

- Check application logs: `docker-compose logs -f app`
- Check Rails console: `docker-compose exec app rails console`
- Review environment variables: `docker-compose config`
- Consult documentation: This file!
- Ask team on Slack: #backend-support

---

## Next Steps

After setting up environments:

1. ✅ Development environment running locally
2. ✅ All services accessible
3. ✅ Tests passing
4. ⬜ Staging environment deployed
5. ⬜ CI/CD pipeline configured
6. ⬜ Monitoring dashboards set up
7. ⬜ Production infrastructure provisioned
8. ⬜ Production deployment tested

---

## Document Updates

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2025-11-04 | Initial environment setup documentation | DevOps Team |

---

**Security Note:** Never commit `.env` files with real credentials to version control. Always use `.env.example` templates and populate actual values locally or via CI/CD secrets.
