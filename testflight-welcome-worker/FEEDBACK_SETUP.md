# TestFlight Feedback Parser Setup

This guide covers deploying the feedback email handler enhancement to the existing testflight-welcome-worker.

## What's Been Added

The worker now handles **both**:
1. ✅ **Outgoing welcome emails** (existing cron functionality)
2. 🆕 **Incoming feedback emails** → Creates Linear issues with `beta-feedback` label

## Prerequisites

You'll need API keys for:
- **Linear** (for creating issues)
- **Amplitude** (for tracking events)

## Setup Steps

### Step 1: Create KV Namespace for Feedback Deduplication

```bash
cd testflight-welcome-worker
npx wrangler kv:namespace create FEEDBACK_HASHES
```

This will output something like:
```
🌀 Creating namespace with title "testflight-welcome-worker-FEEDBACK_HASHES"
✨ Success!
Add the following to your wrangler.toml:
[[kv_namespaces]]
binding = "FEEDBACK_HASHES"
id = "abc123def456..."
```

Copy the `id` value and update `wrangler.toml` line 25:
```toml
[[kv_namespaces]]
binding = "FEEDBACK_HASHES"
id = "abc123def456..."  # Replace TBD with your actual ID
```

### Step 2: Get Linear API Key

1. Go to [Linear Settings → API](https://linear.app/settings/api)
2. Click **Create new API key**
3. Name it "TestFlight Feedback Worker"
4. Copy the API key (starts with `lin_api_...`)

### Step 3: Get Amplitude API Key

1. Go to your [Amplitude project](https://analytics.amplitude.com/)
2. Navigate to **Settings** → **Projects** → Select your project
3. Copy the **API Key** (under Project Settings)

### Step 4: Set Secrets

Run these commands and paste the values when prompted:

```bash
# Linear API key
npx wrangler secret put LINEAR_API_KEY
# Paste your Linear API key when prompted

# Amplitude API key
npx wrangler secret put AMPLITUDE_API_KEY
# Paste your Amplitude API key when prompted
```

### Step 5: Deploy

```bash
npx wrangler deploy
```

The worker will deploy with:
- ✅ Existing cron (welcome emails every 15 min)
- 🆕 Email routing for `support@quillstack.io` and `feedback@quillstack.io`

### Step 6: Configure Cloudflare Email Routing

After deployment, you need to configure email routing in Cloudflare:

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Select your domain (`quillstack.io`)
3. Navigate to **Email** → **Email Routing**
4. Verify your domain is set up for email routing
5. The worker should now appear as a destination option

**Email addresses that will trigger the feedback handler:**
- `support@quillstack.io` (replies to welcome emails)
- `feedback@quillstack.io` (dedicated feedback address)

## How It Works

### Email Flow

```
TestFlight Tester
    ↓ (replies to welcome email or sends to feedback@)
support@quillstack.io
    ↓
Cloudflare Email Routing
    ↓
testflight-welcome-worker (email handler)
    ↓
1. Parse email content
2. Check for duplicates (7-day window)
3. Create Linear issue with beta-feedback label
4. Track event in Amplitude
5. Store hash to prevent future duplicates
```

### What Gets Created in Linear

**Issue Title:** `TestFlight: [first line of feedback]`

**Issue Description:**
```markdown
## Feedback

[Full feedback text]

## Metadata

**Submitted by:** tester@example.com
**Received:** Jan 3, 2026, 10:30 AM

### Device Information
**Device:** iPhone 15 Pro
**iOS Version:** 18.2
```

**Labels:** `beta-feedback` (orange badge)

### Amplitude Event

**Event Type:** `beta_feedback_received`

**Event Properties:**
- `feedback_length`: Character count
- `has_device_info`: Boolean
- `linear_issue_id`: Issue identifier (e.g., `QUI-71`)

## Testing

### Test with Manual Email

Send a test email to `support@quillstack.io` from your email address:

**Subject:** `Test feedback from TestFlight`

**Body:**
```
The app crashed when I tried to scan a note with very small handwriting.

Device: iPhone 14 Pro
iOS: 18.1.1
```

**Expected Result:**
- Linear issue created with title: `TestFlight: The app crashed when I tried to scan a note`
- Issue has `beta-feedback` label
- Amplitude event tracked
- Subsequent identical feedback within 7 days is ignored

### View Logs

```bash
npx wrangler tail
```

Watch for:
- `📧 Received feedback email from: you@example.com`
- `✅ Created Linear issue: QUI-XX`
- `✅ Event tracked in Amplitude`
- `🎉 Feedback processed successfully`

### Verify in Linear

1. Go to [Linear Issues](https://linear.app/quillstack/team/QUI/all)
2. Filter by label: `beta-feedback`
3. You should see your test issue

## Monitoring

### Cloudflare Dashboard

View worker metrics:
- **Workers & Pages** → `testflight-welcome-worker` → **Metrics**
- Track email handler invocations
- Monitor error rates

### Linear

Filter issues by `beta-feedback` label to see all TestFlight feedback in one view.

### Amplitude

View the `beta_feedback_received` event in your Amplitude dashboard to track:
- Feedback volume over time
- Which testers are most active
- Feedback patterns

## Deduplication

Duplicate feedback is detected using SHA-256 hash of:
- Tester email
- Normalized feedback text (lowercase, whitespace collapsed)

**Deduplication window:** 7 days

**Example:**
- Day 1: Tester sends "App crashes on startup" → Linear issue created
- Day 3: Same tester sends "App crashes on startup" → Skipped (duplicate)
- Day 10: Same tester sends "App crashes on startup" → New Linear issue (7 days passed)

## Troubleshooting

### Emails not creating Linear issues

1. Check worker logs: `npx wrangler tail`
2. Verify email routing is configured in Cloudflare dashboard
3. Ensure `LINEAR_API_KEY` secret is set correctly
4. Check that Linear team ID and label ID match in `wrangler.toml`

### "Duplicate feedback" being skipped incorrectly

Check KV namespace:
```bash
npx wrangler kv:key list --namespace-id=<FEEDBACK_HASHES_ID>
```

To clear a hash and allow re-processing:
```bash
npx wrangler kv:key delete --namespace-id=<FEEDBACK_HASHES_ID> <hash>
```

### Amplitude not tracking

- Verify `AMPLITUDE_API_KEY` is correct
- Check Amplitude project settings
- Note: Amplitude failures don't block issue creation (non-blocking)

## Cost

All services remain **free tier**:

| Service | Free Tier | Usage | Cost |
|---------|-----------|-------|------|
| Cloudflare Email Routing | Unlimited | All feedback emails | **$0** |
| Cloudflare KV (new namespace) | 100K reads, 1K writes/day | Minimal | **$0** |
| Linear API | Unlimited | Issue creation | **$0** |
| Amplitude | 10M events/month | <1K events/month | **$0** |

**Total: Still $0/month**

## Future Enhancements

- [ ] Parse structured TestFlight feedback format from Apple
- [ ] Auto-tag issues based on feedback content (crash, feature request, bug)
- [ ] Reply to feedback emails with acknowledgment
- [ ] Weekly digest of feedback to Slack
- [ ] Sentiment analysis on feedback text
- [ ] Link feedback to specific app versions/builds

## Related Files

| File | Purpose |
|------|---------|
| `src/index.ts` | Main worker with email handler |
| `src/feedbackParser.ts` | Email parsing logic |
| `src/linearClient.ts` | Linear GraphQL API client |
| `src/amplitudeClient.ts` | Amplitude HTTP API client |
| `src/deduplicator.ts` | Hash-based deduplication |
| `wrangler.toml` | Worker configuration |

## Support

For issues:
- Check worker logs: `npx wrangler tail`
- Review Cloudflare dashboard for errors
- Check Linear issue QUI-70 for context
