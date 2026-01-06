# Worker Health Monitor

Cloudflare Worker with cron trigger that monitors the health of other Cloudflare Workers and creates Linear issues when problems are detected.

## Features

- ✅ Automatic health checks every 5 minutes via cron trigger
- ✅ Monitors multiple workers in parallel
- ✅ Tracks consecutive failures and sustained slow response times
- ✅ Creates Linear issues for critical problems
- ✅ Logs metrics to Amplitude for analysis
- ✅ Stores state in KV for persistent tracking
- ✅ Prevents duplicate issue creation
- ✅ Manual testing endpoint for validation

## Monitored Workers

Currently monitors:
- `testflight-welcome-worker` - TestFlight beta tester welcome emails
- `api-proxy-worker` - API proxy service

## Alert Conditions

### Consecutive Failures
Creates a Linear issue when:
- Worker fails **>3 consecutive health checks**
- Includes error details and failure count

### Sustained Slow Response
Creates a Linear issue when:
- Worker response time **>5 seconds**
- Sustained for **>15 minutes**
- Includes performance metrics

## Setup Instructions

### 1. Create KV Namespace

```bash
cd worker-health-monitor
npm install
wrangler kv:namespace create HEALTH_METRICS
```

This will output something like:
```
{ binding = "HEALTH_METRICS", id = "abc123..." }
```

Update `wrangler.toml` with the actual KV namespace ID.

### 2. Configure Worker URLs

Update `wrangler.toml` with your actual worker URLs:

```toml
[vars]
TESTFLIGHT_WORKER_URL = "https://testflight-welcome-worker.YOUR_SUBDOMAIN.workers.dev"
API_PROXY_WORKER_URL = "https://api-proxy-worker.YOUR_SUBDOMAIN.workers.dev"
```

### 3. Set Secrets

Set the required API keys:

```bash
# Linear API key
wrangler secret put LINEAR_API_KEY
# Paste your Linear API key when prompted

# Amplitude API key
wrangler secret put AMPLITUDE_API_KEY
# Paste your Amplitude API key when prompted
```

### 4. Deploy

```bash
npm run deploy
```

## Testing

### Manual Health Check

Trigger an immediate health check (without waiting for cron):

```bash
curl -X POST https://worker-health-monitor.YOUR_SUBDOMAIN.workers.dev/check-now
```

### Check Worker Status

Get current metrics for a specific worker:

```bash
curl https://worker-health-monitor.YOUR_SUBDOMAIN.workers.dev/metrics/testflight-welcome-worker
```

### Monitor Logs

Watch real-time logs:

```bash
npm run tail
```

## Architecture

### Components

- **`index.ts`** - Main entry point with cron and HTTP handlers
- **`healthChecker.ts`** - Core health check logic and alert creation
- **`kvStore.ts`** - KV storage helpers for state persistence
- **`linearClient.ts`** - Linear API client for issue creation
- **`amplitudeClient.ts`** - Amplitude API client for metrics tracking
- **`types.ts`** - TypeScript type definitions

### Data Flow

1. **Cron Trigger** (every 5 min) → Check all workers in parallel
2. **Health Check** → HTTP GET to worker endpoint
3. **Result Processing** → Update state in KV
4. **Threshold Check** → Evaluate alert conditions
5. **Alert Creation** → Create Linear issue if needed
6. **Metrics Logging** → Track event in Amplitude

### KV Storage Keys

- `state:{workerName}` - Current health state (failures, timestamps)
- `metrics:{workerName}` - Aggregated metrics (uptime, avg response time)

## Configuration

### Thresholds

Adjust in `wrangler.toml`:

```toml
[vars]
MAX_CONSECUTIVE_FAILURES = 3
RESPONSE_TIME_THRESHOLD_MS = 5000
SUSTAINED_SLOW_DURATION_MIN = 15
```

### Cron Schedule

Modify in `wrangler.toml`:

```toml
[triggers]
crons = ["*/5 * * * *"]  # Every 5 minutes
```

Cron syntax: `minute hour day month dayOfWeek`

Examples:
- `*/5 * * * *` - Every 5 minutes
- `*/15 * * * *` - Every 15 minutes
- `0 * * * *` - Every hour

## Monitoring the Monitor

The health monitor itself exposes a health endpoint:

```bash
curl https://worker-health-monitor.YOUR_SUBDOMAIN.workers.dev/health
```

Returns:
```json
{
  "status": "ok",
  "service": "worker-health-monitor",
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

## Troubleshooting

### Worker not triggering

Check cron trigger status:
```bash
wrangler tail --format pretty
```

Verify cron is configured in `wrangler.toml`.

### Duplicate issues being created

Check the `hasRecentIssue()` logic in `kvStore.ts`. By default, it prevents duplicate issues within 60 minutes.

### Missing metrics in Amplitude

Verify `AMPLITUDE_API_KEY` secret is set:
```bash
wrangler secret list
```

Check logs for Amplitude API errors.

### Linear issues not created

Verify `LINEAR_API_KEY` secret and team ID in `healthChecker.ts`:
```typescript
const teamId = 'YOUR_TEAM_ID';
```

Get team ID from Linear MCP or Linear API.

## Development

### Local Development

```bash
npm run dev
```

### Type Checking

TypeScript strict mode is enabled. All types are defined in `types.ts`.

### Adding New Workers

Edit `src/index.ts` and add to the `workersToMonitor` array:

```typescript
const workersToMonitor: WorkerConfig[] = [
  // ... existing workers
  {
    name: 'new-worker',
    url: env.NEW_WORKER_URL,
    healthEndpoint: '/health' // optional
  }
];
```

Update `wrangler.toml` with the new worker URL.

## License

MIT
