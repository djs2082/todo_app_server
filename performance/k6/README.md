# k6 Performance Tests

## Quick Start

```bash
# Install k6
brew install k6  # macOS
# or
sudo apt-get install k6  # Linux

# Run load test
k6 run load-test.js

# Run against staging
API_URL=https://staging-api.your-domain.com k6 run load-test.js

# Run with output
k6 run --out json=results.json load-test.js
```

## Test Scripts

- `load-test.js` - Standard load testing (50-100 users)
- `stress-test.js` - Stress testing (up to 400 users)
- `spike-test.js` - Spike testing (sudden load increase)
- `soak-test.js` - Soak testing (sustained load over hours)

## Environment Variables

- `API_URL` - Base URL for API (default: http://localhost:3000)
- `TEST_USER_EMAIL` - Test user email
- `TEST_USER_PASSWORD` - Test user password

## Thresholds

- p95 response time: < 200ms
- p99 response time: < 500ms
- Error rate: < 1%
- Throughput: > 100 req/sec
