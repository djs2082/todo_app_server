# Performance Testing Setup

## Document Information
- **Version:** 1.0
- **Last Updated:** 2025-11-04
- **Status:** Sprint 0 - Performance Testing Framework
- **Purpose:** Guide for setting up and running performance tests

---

## Table of Contents
1. [Overview](#overview)
2. [Tools and Setup](#tools-and-setup)
3. [Load Testing with k6](#load-testing-with-k6)
4. [Benchmark Testing](#benchmark-testing)
5. [Database Performance](#database-performance)
6. [Profiling](#profiling)
7. [Continuous Performance Testing](#continuous-performance-testing)
8. [Metrics and Reporting](#metrics-and-reporting)

---

## Overview

### Performance Testing Goals

| Metric | Target | Tool |
|--------|--------|------|
| **Response Time (p95)** | < 200ms | k6, New Relic |
| **Response Time (p99)** | < 500ms | k6, New Relic |
| **Throughput** | > 1000 req/sec | k6 |
| **Error Rate** | < 1% | k6, Sentry |
| **Database Query Time** | < 50ms | rack-mini-profiler, Bullet |
| **Memory Usage** | < 512MB per process | memory_profiler |
| **CPU Usage** | < 70% average | top, New Relic |

### Testing Types

```
┌──────────────────────────────────────────────────┐
│           Performance Testing Types               │
├──────────────────────────────────────────────────┤
│                                                  │
│  1. Load Testing      Test with expected load   │
│  2. Stress Testing    Test beyond capacity      │
│  3. Spike Testing     Test sudden load increase │
│  4. Soak Testing      Test sustained load       │
│  5. Benchmark         Compare performance       │
│  6. Profiling         Find bottlenecks          │
│                                                  │
└──────────────────────────────────────────────────┘
```

---

## Tools and Setup

### Required Tools

| Tool | Purpose | Installation |
|------|---------|--------------|
| **k6** | Load testing | `brew install k6` |
| **Apache Bench** | Quick benchmarks | `brew install ab` |
| **rack-mini-profiler** | Request profiling | Gem |
| **bullet** | N+1 query detection | Gem |
| **memory_profiler** | Memory analysis | Gem |
| **stackprof** | CPU profiling | Gem |

### Install Performance Gems

Add to `Gemfile`:

```ruby
group :development do
  gem 'rack-mini-profiler'
  gem 'memory_profiler'
  gem 'stackprof'
  gem 'derailed_benchmarks'
end

group :development, :test do
  gem 'bullet'
  gem 'benchmark-ips'
end
```

Install:
```bash
bundle install
```

---

## Load Testing with k6

### What is k6?

k6 is a modern load testing tool that:
- Uses JavaScript for test scripts
- Provides detailed metrics
- Integrates with CI/CD
- Supports thresholds and assertions

### Installation

```bash
# macOS
brew install k6

# Linux
sudo apt-get install k6

# Windows
choco install k6
```

### Basic Load Test Script

**File:** `performance/k6/load-test.js`

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const apiDuration = new Trend('api_duration');

// Test configuration
export const options = {
  stages: [
    { duration: '1m', target: 50 },    // Ramp up to 50 users
    { duration: '3m', target: 50 },    // Stay at 50 users for 3 minutes
    { duration: '1m', target: 100 },   // Ramp up to 100 users
    { duration: '3m', target: 100 },   // Stay at 100 users
    { duration: '1m', target: 0 },     // Ramp down to 0
  ],
  thresholds: {
    http_req_duration: ['p(95)<200', 'p(99)<500'],  // 95% < 200ms, 99% < 500ms
    http_req_failed: ['rate<0.01'],                 // Error rate < 1%
    errors: ['rate<0.01'],
  },
};

// Test data
const BASE_URL = __ENV.API_URL || 'http://localhost:3000';
let authToken = '';

// Setup function (runs once)
export function setup() {
  // Login to get auth token
  const loginRes = http.post(`${BASE_URL}/api/v1/auth/login`, JSON.stringify({
    email: 'test@example.com',
    password: 'password123'
  }), {
    headers: { 'Content-Type': 'application/json' },
  });

  check(loginRes, {
    'login successful': (r) => r.status === 200,
  });

  return { token: JSON.parse(loginRes.body).access_token };
}

// Main test function
export default function(data) {
  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${data.token}`,
    },
  };

  // Test 1: List tasks
  let res = http.get(`${BASE_URL}/api/v1/tasks`, params);
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 200ms': (r) => r.timings.duration < 200,
  });
  errorRate.add(res.status !== 200);
  apiDuration.add(res.timings.duration);

  sleep(1);

  // Test 2: Create task
  res = http.post(`${BASE_URL}/api/v1/tasks`, JSON.stringify({
    title: 'Load test task',
    description: 'Created by k6 load test',
    priority: 1
  }), params);

  check(res, {
    'task created': (r) => r.status === 201,
  });
  errorRate.add(res.status !== 201);

  const taskId = JSON.parse(res.body).id;

  sleep(1);

  // Test 3: Get task
  res = http.get(`${BASE_URL}/api/v1/tasks/${taskId}`, params);
  check(res, {
    'task retrieved': (r) => r.status === 200,
  });
  errorRate.add(res.status !== 200);

  sleep(1);

  // Test 4: Update task
  res = http.patch(`${BASE_URL}/api/v1/tasks/${taskId}`, JSON.stringify({
    status: 'in_progress'
  }), params);

  check(res, {
    'task updated': (r) => r.status === 200,
  });
  errorRate.add(res.status !== 200);

  sleep(1);

  // Test 5: Delete task
  res = http.del(`${BASE_URL}/api/v1/tasks/${taskId}`, null, params);
  check(res, {
    'task deleted': (r) => r.status === 204,
  });
  errorRate.add(res.status !== 204);

  sleep(2);
}

// Teardown function (runs once)
export function teardown(data) {
  console.log('Load test completed');
}
```

### Running Load Tests

```bash
# Basic run
k6 run performance/k6/load-test.js

# Run with custom target
API_URL=https://staging-api.todoapp.com k6 run performance/k6/load-test.js

# Run with output to file
k6 run --out json=results.json performance/k6/load-test.js

# Run with Cloud output
k6 run --out cloud performance/k6/load-test.js
```

### Stress Test Script

**File:** `performance/k6/stress-test.js`

```javascript
export const options = {
  stages: [
    { duration: '2m', target: 100 },   // Ramp up to 100 users
    { duration: '5m', target: 100 },   // Stay at 100
    { duration: '2m', target: 200 },   // Ramp up to 200
    { duration: '5m', target: 200 },   // Stay at 200
    { duration: '2m', target: 300 },   // Push to 300
    { duration: '5m', target: 300 },   // Stay at 300
    { duration: '2m', target: 400 },   // Push to 400
    { duration: '5m', target: 400 },   // Stay at 400 (breaking point?)
    { duration: '5m', target: 0 },     // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(99)<1000'],  // Allow higher latency
    http_req_failed: ['rate<0.05'],     // Allow 5% error rate
  },
};

// ... rest similar to load test
```

### Spike Test

**File:** `performance/k6/spike-test.js`

```javascript
export const options = {
  stages: [
    { duration: '10s', target: 100 },  // Normal load
    { duration: '1m', target: 100 },
    { duration: '10s', target: 1000 }, // Spike!
    { duration: '3m', target: 1000 },  // Stay high
    { duration: '10s', target: 100 },  // Back to normal
    { duration: '1m', target: 100 },
    { duration: '10s', target: 0 },
  ],
};
```

---

## Benchmark Testing

### Apache Bench (ab)

Quick benchmarks:

```bash
# Simple GET request benchmark
ab -n 1000 -c 10 http://localhost:3000/health

# POST request with auth
ab -n 100 -c 10 -H "Authorization: Bearer TOKEN" \
   -H "Content-Type: application/json" \
   -p post-data.json \
   http://localhost:3000/api/v1/tasks

# Benchmark specific endpoint
ab -n 10000 -c 100 -H "Authorization: Bearer TOKEN" \
   http://localhost:3000/api/v1/tasks
```

### Benchmark-ips (Ruby)

**File:** `performance/benchmarks/controller_benchmark.rb`

```ruby
require 'benchmark/ips'
require_relative '../../config/environment'

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  user = User.first
  token = JsonWebToken.encode(user_id: user.id)

  x.report('GET /api/v1/tasks') do
    # Simulate controller action
    TasksController.new.index
  end

  x.report('POST /api/v1/tasks') do
    Task.create!(
      user: user,
      title: 'Benchmark task',
      priority: 1
    )
  end

  x.compare!
end
```

Run:
```bash
ruby performance/benchmarks/controller_benchmark.rb
```

### Method-Level Benchmarks

```ruby
# performance/benchmarks/task_operations.rb
require 'benchmark/ips'
require_relative '../../config/environment'

Benchmark.ips do |x|
  x.report('Task.where with eager loading') do
    Task.includes(:user).where(status: 'pending').to_a
  end

  x.report('Task.where without eager loading') do
    Task.where(status: 'pending').to_a
  end

  x.compare!
end
```

---

## Database Performance

### Bullet (N+1 Query Detection)

**Configuration:** `config/environments/development.rb`

```ruby
config.after_initialize do
  Bullet.enable = true
  Bullet.alert = false
  Bullet.bullet_logger = true
  Bullet.console = true
  Bullet.rails_logger = true
  Bullet.add_footer = true

  # Raise error in tests
  if Rails.env.test?
    Bullet.raise = true
  end
end
```

Bullet will warn about:
- N+1 queries
- Unused eager loading
- Missing counter cache
- Unnecessary eager loading

### Database Query Analysis

```bash
# Rails console
rails console

# Enable query logging
ActiveRecord::Base.logger = Logger.new(STDOUT)

# Run query and see SQL
Task.includes(:user).where(status: 'pending').to_a

# Explain query
Task.where(status: 'pending').explain

# Find slow queries
# In MySQL slow query log
```

### Database Profiling

```ruby
# In controller or model
ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
  duration = finish - start
  if duration > 0.05  # 50ms
    Rails.logger.warn "Slow query (#{duration.round(2)}s): #{payload[:sql]}"
  end
end
```

---

## Profiling

### Rack Mini Profiler

Automatically enabled in development.

Access profiling:
```
http://localhost:3000/api/v1/tasks?pp=help
http://localhost:3000/api/v1/tasks?pp=flamegraph
```

### Memory Profiler

```ruby
# script/profile_memory.rb
require 'memory_profiler'
require_relative '../config/environment'

report = MemoryProfiler.report do
  # Code to profile
  100.times do
    Task.create!(
      user: User.first,
      title: 'Memory test',
      priority: 1
    )
  end
end

report.pretty_print
```

Run:
```bash
ruby script/profile_memory.rb
```

### Stack Profiler (CPU)

```ruby
# script/profile_cpu.rb
require 'stackprof'
require_relative '../config/environment'

StackProf.run(mode: :cpu, out: 'tmp/stackprof-cpu.dump') do
  # Code to profile
  1000.times do
    Task.where(status: 'pending').to_a
  end
end

# Generate report
# stackprof tmp/stackprof-cpu.dump --text
```

Run:
```bash
ruby script/profile_cpu.rb
stackprof tmp/stackprof-cpu.dump --text --limit 20
```

### Derailed Benchmarks

Find memory leaks and performance issues:

```bash
# Measure memory usage
bundle exec derailed bundle:mem

# Find memory leaks
bundle exec derailed exec perf:mem

# Measure boot time
bundle exec derailed bundle:objects

# Measure individual endpoints
PATH_TO_HIT=/api/v1/tasks bundle exec derailed exec perf:mem
```

---

## Continuous Performance Testing

### GitHub Actions Integration

**File:** `.github/workflows/performance.yml`

```yaml
name: Performance Tests

on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM
  workflow_dispatch:

jobs:
  load-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install k6
        run: |
          sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
          echo "deb https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
          sudo apt-get update
          sudo apt-get install k6

      - name: Run load test
        run: |
          k6 run --out json=results.json performance/k6/load-test.js
        env:
          API_URL: ${{ secrets.STAGING_API_URL }}

      - name: Upload results
        uses: actions/upload-artifact@v4
        with:
          name: performance-results
          path: results.json

      - name: Analyze results
        run: |
          # Parse results and fail if thresholds not met
          python3 performance/scripts/analyze_results.py results.json
```

### Performance Budgets

Set performance budgets and fail builds if exceeded:

```javascript
// In k6 script
export const options = {
  thresholds: {
    // Performance budgets
    'http_req_duration': ['p(95)<200'],    // Fail if p95 > 200ms
    'http_req_failed': ['rate<0.01'],      // Fail if error rate > 1%
    'http_reqs': ['rate>100'],             // Fail if < 100 req/sec
  },
};
```

---

## Metrics and Reporting

### Key Metrics

**Response Times:**
- p50 (median)
- p95 (95th percentile)
- p99 (99th percentile)
- p99.9 (99.9th percentile)

**Throughput:**
- Requests per second
- Data transferred

**Errors:**
- Error rate
- Error types
- Failed requests

**Resources:**
- CPU usage
- Memory usage
- Database connections

### k6 Output Formats

```bash
# JSON
k6 run --out json=results.json script.js

# CSV
k6 run --out csv=results.csv script.js

# InfluxDB (for Grafana)
k6 run --out influxdb=http://localhost:8086/k6 script.js

# Prometheus
k6 run --out prometheus script.js

# k6 Cloud
k6 run --out cloud script.js
```

### Sample Report

```
scenarios: (100.00%) 1 scenario, 100 max VUs, 10m30s max duration
          default: Up to 100 looping VUs for 10m0s over 5 stages

     ✓ status is 200
     ✓ response time < 200ms

     checks.........................: 100.00% ✓ 50000     ✗ 0
     data_received..................: 75 MB   125 kB/s
     data_sent......................: 25 MB   42 kB/s
     http_req_blocked...............: avg=1.2ms    min=1µs     med=3µs    max=150ms  p(90)=5µs    p(95)=7µs
     http_req_connecting............: avg=750µs    min=0s      med=0s     max=100ms  p(90)=0s     p(95)=0s
     http_req_duration..............: avg=120ms    min=50ms    med=110ms  max=500ms  p(90)=180ms  p(95)=200ms
       { expected_response:true }...: avg=120ms    min=50ms    med=110ms  max=500ms  p(90)=180ms  p(95)=200ms
     http_req_failed................: 0.00%   ✓ 0         ✗ 50000
     http_req_receiving.............: avg=500µs    min=20µs    med=300µs  max=10ms   p(90)=800µs  p(95)=1ms
     http_req_sending...............: avg=200µs    min=10µs    med=150µs  max=5ms    p(90)=300µs  p(95)=400µs
     http_req_tls_handshaking.......: avg=0s       min=0s      med=0s     max=0s     p(90)=0s     p(95)=0s
     http_req_waiting...............: avg=119ms    min=49ms    med=109ms  max=499ms  p(90)=179ms  p(95)=199ms
     http_reqs......................: 50000   83.33/s
     iteration_duration.............: avg=1.2s     min=1s      med=1.15s  max=2s     p(90)=1.4s   p(95)=1.5s
     iterations.....................: 10000   16.66/s
     vus............................: 100     min=0       max=100
     vus_max........................: 100     min=100     max=100
```

---

## Best Practices

### 1. Test Realistic Scenarios

- Use production-like data volumes
- Simulate real user behavior
- Include authentication
- Test all critical endpoints

### 2. Set Baselines

- Record initial metrics
- Compare against baselines
- Track trends over time
- Alert on regressions

### 3. Test Regularly

- Run in CI/CD
- Daily/weekly scheduled tests
- Before major releases
- After infrastructure changes

### 4. Monitor During Tests

- Watch application metrics
- Monitor database
- Check error logs
- Observe resource usage

### 5. Test Different Scenarios

- Normal load
- Peak load
- Sustained load
- Spike traffic
- Gradual ramp-up

### 6. Fix Performance Issues

- Profile to find bottlenecks
- Optimize queries
- Add caching
- Scale resources
- Re-test to verify

---

## Troubleshooting

### High Response Times

1. Check database queries (N+1)
2. Review slow query log
3. Check external API calls
4. Look for CPU/memory issues
5. Review caching strategy

### High Error Rates

1. Check application logs
2. Review error tracking (Sentry)
3. Check rate limiting
4. Verify database connections
5. Check third-party services

### Memory Leaks

1. Use memory profiler
2. Check for circular references
3. Review background jobs
4. Monitor memory over time
5. Use heap dumps

---

## Next Steps

1. ✅ Performance testing documentation created
2. ⬜ Install k6
3. ⬜ Create load test scripts
4. ⬜ Set up Bullet in development
5. ⬜ Configure rack-mini-profiler
6. ⬜ Run initial baseline tests
7. ⬜ Add performance tests to CI
8. ⬜ Set up monitoring dashboards
9. ⬜ Document performance baselines
10. ⬜ Schedule regular performance reviews

---

**Document Version:** 1.0
**Last Updated:** 2025-11-04
**Maintained by:** Performance Team
