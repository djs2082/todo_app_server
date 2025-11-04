# Monitoring & Observability Setup

## Document Information
- **Version:** 1.0
- **Last Updated:** 2025-11-04
- **Status:** Sprint 0 - Monitoring Configuration
- **Purpose:** Complete guide for application monitoring and observability

---

## Table of Contents
1. [Overview](#overview)
2. [Sentry Error Tracking](#sentry-error-tracking)
3. [New Relic APM](#new-relic-apm)
4. [Prometheus Metrics](#prometheus-metrics)
5. [Logging Strategy](#logging-strategy)
6. [Health Checks](#health-checks)
7. [Alerting Rules](#alerting-rules)
8. [Dashboards](#dashboards)

---

## Overview

### Monitoring Stack

```
┌─────────────────────────────────────────────────────────┐
│                   Application Layer                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │  Sentry  │  │New Relic │  │Prometheus│              │
│  │  (Errors)│  │  (APM)   │  │ (Metrics)│              │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘              │
└───────┼────────────┼──────────────┼─────────────────────┘
        │            │              │
        ▼            ▼              ▼
┌──────────────────────────────────────────────────────────┐
│              Monitoring Dashboard                         │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐        │
│  │  Sentry    │  │  New Relic │  │  Grafana   │        │
│  │  Dashboard │  │  Dashboard │  │  Dashboard │        │
│  └────────────┘  └────────────┘  └────────────┘        │
└──────────────────────────────────────────────────────────┘
        │            │              │
        ▼            ▼              ▼
┌──────────────────────────────────────────────────────────┐
│                   Alert Channels                          │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐        │
│  │   Slack    │  │  PagerDuty │  │   Email    │        │
│  └────────────┘  └────────────┘  └────────────┘        │
└──────────────────────────────────────────────────────────┘
```

### Monitoring Components

| Component | Purpose | Environment | Cost |
|-----------|---------|-------------|------|
| **Sentry** | Error tracking & performance | Staging, Production | $26/month |
| **New Relic** | APM & transaction tracing | Production | $99/month |
| **Prometheus** | Metrics collection | Staging, Production | Free (self-hosted) |
| **Grafana** | Metrics visualization | Staging, Production | Free (self-hosted) |
| **CloudWatch** | AWS infrastructure logs | Production | Variable |

---

## Sentry Error Tracking

### Configuration

**File:** `config/initializers/sentry.rb`

Sentry is already configured with:
- ✅ Error capture and reporting
- ✅ Performance monitoring (APM)
- ✅ Breadcrumbs for debugging
- ✅ PII filtering (GDPR compliant)
- ✅ Sensitive data sanitization
- ✅ Smart sampling
- ✅ Bot/crawler filtering

### Features Enabled

**1. Error Tracking**
- Automatic error capture
- Stack traces
- User context
- Request details
- Environment info

**2. Performance Monitoring**
- Transaction tracing
- Database query monitoring
- External API calls
- Background job tracking

**3. Sampling Strategy**
```ruby
Health checks: 0% (don't sample)
API endpoints: 5% (production), 50% (staging)
Background jobs: 50%
Default: 10%
```

### Setup Instructions

#### 1. Sign up for Sentry

```bash
# Go to https://sentry.io
# Create account
# Create new project: "todo-app-production"
# Get DSN
```

#### 2. Add DSN to environment

```bash
# .env.production
SENTRY_DSN=https://examplePublicKey@o0.ingest.sentry.io/0
SENTRY_TRACES_SAMPLE_RATE=0.1
SENTRY_PROFILES_SAMPLE_RATE=0.1
```

#### 3. Test Sentry

```ruby
# Rails console
Sentry.capture_message("Test message from console")

# Or trigger an error
raise "Test error for Sentry"
```

#### 4. View in Dashboard

```
https://sentry.io/organizations/your-org/issues/
```

### Best Practices

**Ignore Non-Critical Errors:**
```ruby
# Already configured in sentry.rb
- ActionController::RoutingError (404s)
- ActiveRecord::RecordNotFound (expected)
- Pundit::NotAuthorizedError (authorization)
```

**Custom Error Context:**
```ruby
# In your code
Sentry.set_context("business", {
  account_id: current_account.id,
  user_role: current_user.role
})

# Capture with extra info
Sentry.capture_exception(exception, extra: { task_id: task.id })
```

**Performance Tracking:**
```ruby
# Track custom transactions
Sentry.with_transaction(op: "task.process") do
  process_task(task)
end
```

---

## New Relic APM

### Configuration

**File:** `config/newrelic.yml`

Features configured:
- ✅ Application performance monitoring
- ✅ Distributed tracing
- ✅ Database query analysis
- ✅ External service calls
- ✅ Transaction traces
- ✅ Error tracking
- ✅ Slow SQL detection

### Setup Instructions

#### 1. Sign up for New Relic

```bash
# Go to https://newrelic.com
# Create account
# Get license key
```

#### 2. Add to Gemfile

```ruby
# Add to Gemfile
gem 'newrelic_rpm'
```

```bash
bundle install
```

#### 3. Configure environment variables

```bash
# .env.production
NEW_RELIC_LICENSE_KEY=your_license_key_here
NEW_RELIC_APP_NAME=TodoApp Production
NEW_RELIC_LOG=stdout
```

#### 4. Deploy and verify

```bash
# After deployment, check New Relic dashboard
# https://one.newrelic.com/
```

### Features

**Application Monitoring:**
- Response time tracking
- Throughput (requests/min)
- Error rate
- Apdex score
- Transaction breakdown

**Database Monitoring:**
- Query performance
- Slow queries
- N+1 detection
- Connection pool stats

**External Services:**
- API call tracking
- Third-party service latency
- Redis/cache performance

**Transaction Traces:**
- Detailed call stack
- SQL queries
- Method-level timing

### Custom Instrumentation

```ruby
# Add custom instrumentation
class TasksController < ApplicationController
  include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation

  def complex_operation
    perform_action_with_newrelic_trace(
      name: 'Custom/TaskProcessing',
      category: :task
    ) do
      # Your code here
    end
  end
end

# Custom metrics
::NewRelic::Agent.record_metric('Custom/TasksProcessed', task_count)

# Custom events
::NewRelic::Agent.record_custom_event('TaskCompleted', {
  task_id: task.id,
  duration: task.duration,
  priority: task.priority
})
```

---

## Prometheus Metrics

### Configuration

**File:** `config/initializers/prometheus.rb`

### Setup Instructions

#### 1. Add gems

```ruby
# Gemfile
gem 'prometheus_exporter'
gem 'prometheus-client'
```

```bash
bundle install
```

#### 2. Start Prometheus exporter

```bash
# In production/staging
bundle exec prometheus_exporter

# Or via Docker
docker run -p 9394:9394 prom/prometheus
```

#### 3. Configure middleware

```ruby
# config/application.rb
if Rails.env.production? || Rails.env.staging?
  config.middleware.use PrometheusExporter::Middleware
end
```

#### 4. Access metrics

```bash
curl http://localhost:9394/metrics
```

### Custom Metrics

```ruby
# Counter
require 'prometheus_exporter/client'

client = PrometheusExporter::Client.default
client.send_json(
  type: "counter",
  name: "tasks_created_total",
  help: "Total number of tasks created",
  labels: { priority: "high" }
)

# Gauge
client.send_json(
  type: "gauge",
  name: "active_tasks",
  help: "Number of active tasks",
  value: Task.in_progress.count
)

# Histogram
client.send_json(
  type: "histogram",
  name: "task_completion_duration_seconds",
  help: "Task completion duration",
  value: duration_in_seconds
)
```

### Standard Metrics Exported

```
# HTTP requests
http_requests_total
http_request_duration_seconds

# Ruby VM
ruby_gc_duration_seconds
ruby_memory_bytes

# Process
process_cpu_seconds_total
process_resident_memory_bytes

# Database
db_query_duration_seconds
db_connection_pool_size
```

---

## Logging Strategy

### Log Levels

| Environment | Level | Output |
|-------------|-------|--------|
| Development | DEBUG | STDOUT |
| Test | WARN | STDOUT |
| Staging | INFO | STDOUT + File |
| Production | WARN | STDOUT + Aggregator |

### Structured Logging

```ruby
# config/environments/production.rb
config.log_formatter = proc do |severity, datetime, progname, msg|
  {
    timestamp: datetime.iso8601,
    severity: severity,
    progname: progname,
    message: msg,
    environment: Rails.env,
    hostname: ENV['HOSTNAME']
  }.to_json + "\n"
end
```

### Log Aggregation

**Options:**
1. **AWS CloudWatch** (if on AWS)
2. **ELK Stack** (Elasticsearch, Logstash, Kibana)
3. **Loki + Grafana** (lightweight alternative)
4. **Datadog Logs**

### Important Events to Log

```ruby
# User authentication
Rails.logger.info({
  event: 'user.login',
  user_id: user.id,
  ip: request.remote_ip,
  user_agent: request.user_agent
}.to_json)

# Task operations
Rails.logger.info({
  event: 'task.created',
  task_id: task.id,
  created_by: current_user.id,
  account_id: current_account.id
}.to_json)

# API requests (in middleware)
Rails.logger.info({
  event: 'api.request',
  method: request.method,
  path: request.path,
  status: response.status,
  duration_ms: duration
}.to_json)

# Errors
Rails.logger.error({
  event: 'error.occurred',
  error_class: e.class.name,
  error_message: e.message,
  backtrace: e.backtrace.first(5)
}.to_json)
```

---

## Health Checks

### Endpoints

| Endpoint | Purpose | Timeout |
|----------|---------|---------|
| `/health` | Basic liveness | 5s |
| `/ready` | Readiness (dependencies) | 10s |
| `/live` | Kubernetes liveness | 5s |

### Implementation

**File:** `app/controllers/health_controller.rb`

```ruby
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

    render json: {
      status: all_ok ? 'ready' : 'not_ready',
      checks: checks
    }, status: all_ok ? :ok : :service_unavailable
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

### Kubernetes Probes

```yaml
# k8s/deployment.yaml
livenessProbe:
  httpGet:
    path: /live
    port: 3000
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /ready
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 10
  failureThreshold: 3
```

---

## Alerting Rules

### Sentry Alerts

Configure in Sentry dashboard:

**Critical Alerts:**
- Error rate > 1% (immediate)
- New error introduced (15 min)
- Regression (error returns) (immediate)

**Warning Alerts:**
- Error rate > 0.5% (1 hour)
- Performance degradation > 20% (30 min)

### New Relic Alerts

**Application Alerts:**
- Apdex score < 0.7
- Error rate > 1%
- Response time > 500ms (p95)
- Throughput drop > 50%

**Infrastructure Alerts:**
- CPU > 80% for 5 min
- Memory > 90% for 5 min
- Disk space < 20%

### Prometheus Alerts

**File:** `docker/prometheus/rules/alerts.yml`

```yaml
groups:
  - name: application
    interval: 30s
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.01
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }} per second"

      - alert: SlowResponse
        expr: http_request_duration_seconds{quantile="0.95"} > 0.5
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Slow response times"
          description: "95th percentile is {{ $value }}s"

      - alert: DatabaseConnectionPoolHigh
        expr: db_connection_pool_usage > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Database connection pool usage high"
```

### Notification Channels

**Slack Integration:**
```bash
# In Sentry/New Relic/AlertManager
Webhook URL: https://hooks.slack.com/services/YOUR/WEBHOOK/URL
Channel: #production-alerts
```

**PagerDuty Integration:**
```bash
# For critical alerts only
Integration key: your_pagerduty_key
Escalation policy: Engineering On-Call
```

---

## Dashboards

### Sentry Dashboard

**Default Views:**
- Issues (errors grouped)
- Performance (transactions)
- Releases (deployments)

**Custom Dashboards:**
1. **Error Overview**
   - Error count by type
   - Error rate trend
   - Top 10 errors

2. **Performance Overview**
   - P50, P95, P99 latency
   - Throughput
   - Apdex score

### New Relic Dashboard

**Key Metrics:**
- Application health score
- Response time by endpoint
- Database query performance
- External service latency
- Error rate trends

### Grafana Dashboard

**Panels:**
1. **Application Metrics**
   - Request rate
   - Response time
   - Error rate

2. **Infrastructure**
   - CPU usage
   - Memory usage
   - Disk I/O

3. **Database**
   - Query latency
   - Connection pool
   - Slow queries

4. **Redis**
   - Hit rate
   - Memory usage
   - Command latency

---

## Monitoring Checklist

### Initial Setup
- [ ] Sentry account created
- [ ] Sentry DSN added to environment
- [ ] Sentry tested and verified
- [ ] New Relic account created
- [ ] New Relic license key added
- [ ] New Relic gem installed
- [ ] Prometheus exporter configured
- [ ] Grafana dashboards imported
- [ ] Health check endpoints working
- [ ] Alert channels configured
- [ ] Team notifications set up

### Daily Checks
- [ ] Review error trends
- [ ] Check performance metrics
- [ ] Verify alert rules working
- [ ] Monitor resource usage

### Weekly Reviews
- [ ] Analyze error patterns
- [ ] Review slow queries
- [ ] Check alert fatigue
- [ ] Update alert thresholds
- [ ] Review dashboard relevance

---

## Troubleshooting

### Sentry not reporting errors

```bash
# Check if Sentry is enabled
rails console
> Sentry.configuration.dsn
# Should return your DSN

# Test manually
> Sentry.capture_message("Test")

# Check environment
> Rails.env
# Sentry only active in staging/production
```

### New Relic not showing data

```bash
# Check license key
> NewRelic::Agent.config[:license_key]

# Check if agent is running
> NewRelic::Agent.agent.started?

# View agent log
tail -f log/newrelic_agent.log
```

### Prometheus metrics not available

```bash
# Check if exporter is running
curl http://localhost:9394/metrics

# Check middleware loaded
rails console
> Rails.application.config.middleware

# Restart exporter
bundle exec prometheus_exporter
```

---

## Cost Estimates

| Service | Tier | Monthly Cost | Notes |
|---------|------|--------------|-------|
| Sentry | Team | $26 | 50k errors, 100k transactions |
| New Relic | Pro | $99 | 1 host, 100GB data |
| Prometheus | Self-hosted | $0 | Server costs only |
| Grafana | Self-hosted | $0 | Server costs only |
| CloudWatch | AWS | ~$50 | Logs + metrics |
| **Total** | | **~$175/month** | Production only |

---

## Next Steps

1. ✅ Monitoring configuration created
2. ⬜ Sign up for Sentry account
3. ⬜ Sign up for New Relic account
4. ⬜ Add credentials to environment variables
5. ⬜ Test all monitoring in staging
6. ⬜ Set up Slack notifications
7. ⬜ Configure alert rules
8. ⬜ Create custom dashboards
9. ⬜ Document runbooks for common alerts
10. ⬜ Train team on monitoring tools

---

**Document Version:** 1.0
**Last Updated:** 2025-11-04
**Maintained by:** DevOps Team
