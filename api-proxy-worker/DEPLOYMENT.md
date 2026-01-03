# QuillStack Beta API Proxy - Deployment Guide

This guide walks you through deploying the CloudFlare Worker and configuring the iOS app for beta testing with shared API credits.

## Overview

**What you're setting up:**
- CloudFlare Worker that proxies Anthropic API requests
- Credits system: each beta tester gets 500 credits ($5.00 worth)
- Rate limiting: 10 requests/minute per user
- Automatic credit tracking via CloudFlare KV storage

**Estimated monthly cost for 25 beta testers:** $3-7 (CloudFlare Workers are free tier, you only pay for Anthropic API usage)

---

## Part 1: Deploy the CloudFlare Worker

### Step 1: Install Wrangler CLI

```bash
cd api-proxy-worker
npm install
```

### Step 2: Login to CloudFlare

```bash
npx wrangler login
```

This opens a browser to authorize the CLI.

### Step 3: Create KV Namespace for Credits Storage

```bash
npx wrangler kv:namespace create CREDITS_KV
```

**Output example:**
```
{ binding = "CREDITS_KV", id = "abc123def456..." }
```

Copy the `id` value.

### Step 4: Update wrangler.toml

Edit `wrangler.toml` and replace `YOUR_KV_NAMESPACE_ID` with the ID from Step 3:

```toml
[[kv_namespaces]]
binding = "CREDITS_KV"
id = "abc123def456..."  # Your actual ID here
```

### Step 5: Set Your Anthropic API Key as a Secret

```bash
npx wrangler secret put ANTHROPIC_API_KEY
```

When prompted, paste your Anthropic API key (from console.anthropic.com).

### Step 6: Deploy the Worker

```bash
npm run deploy
```

**Output example:**
```
Deployed to https://quillstack-api-proxy.your-subdomain.workers.dev
```

**Save this URL!** You'll need it for the iOS app configuration.

---

## Part 2: Configure the iOS App

### Option A: Set Default Proxy URL (Recommended for TestFlight)

Edit `Services/SettingsManager.swift` line 1056 and replace the placeholder URL with your worker URL:

```swift
settings.betaAPIProxyURL = "https://quillstack-api-proxy.your-subdomain.workers.dev"
```

Then rebuild the app:
```bash
xcodebuild -scheme QuillStack -configuration Release
```

### Option B: Manual Configuration (For Testing)

1. Launch the app
2. Go to Settings
3. Under "AI Enhancement", find "Beta Access Code"
4. Enter a beta code (e.g., `BETA-TEST-001`)
5. Tap "Save Beta Code"

The app will now use the beta proxy instead of requiring personal API keys.

---

## Part 3: Generate Beta Codes for Testers

Beta codes can be any string. Suggestions:

- `BETA-TEST-001` through `BETA-TEST-025`
- `BETA-[TESTER-NAME]`
- `QS-BETA-[RANDOM]`

**How it works:**
1. When a new beta code is used, the worker automatically creates a user record
2. User gets 500 credits (DEFAULT_CREDITS in `src/index.ts`)
3. Credits are deducted based on token usage
4. When credits reach 0, the app gracefully falls back to basic OCR (no LLM)

---

## Part 4: Distribute to Beta Testers

### Via TestFlight Welcome Email

Add this to your TestFlight instructions:

```
Welcome to the QuillStack Beta!

Your Beta Access Code: BETA-TEST-XXX

To activate AI features:
1. Open QuillStack
2. Tap Settings (gear icon)
3. Under "AI Enhancement", enter your Beta Access Code
4. Tap "Save Beta Code"

You have 500 credits ($5 worth) for AI-powered text enhancement.
The app will show your remaining credits in Settings.

When credits run out, the app continues working with basic OCR.
```

### Via In-Person Beta Testing

1. Open the app on their device
2. Go to Settings > AI Enhancement
3. Enter their beta code
4. Save

---

## Part 5: Monitoring Usage

### View Logs in Real-Time

```bash
cd api-proxy-worker
npm run tail
```

### Check All Beta Users

```bash
npx wrangler kv:key list --namespace-id YOUR_KV_NAMESPACE_ID --prefix "user:"
```

### Get Specific User Info

```bash
npx wrangler kv:key get --namespace-id YOUR_KV_NAMESPACE_ID "user:BETA-TEST-001"
```

**Example output:**
```json
{
  "betaCode": "BETA-TEST-001",
  "creditsRemaining": 347.5,
  "creditsTotal": 500,
  "createdAt": "2026-01-02T15:30:00Z",
  "lastUsedAt": "2026-01-02T16:45:00Z",
  "requestCount": 12
}
```

### Monitor Costs

Check the CloudFlare Workers dashboard:
```
https://dash.cloudflare.com/?to=/:account/workers
```

Anthropic API usage will show in your Anthropic console:
```
https://console.anthropic.com/settings/usage
```

---

## Part 6: Managing Credits

### Give a User More Credits

```bash
npx wrangler kv:key put --namespace-id YOUR_KV_NAMESPACE_ID \
  "user:BETA-TEST-001" \
  '{"betaCode":"BETA-TEST-001","creditsRemaining":1000,"creditsTotal":1000,"createdAt":"2026-01-02T00:00:00Z","lastUsedAt":"2026-01-02T00:00:00Z","requestCount":0}'
```

### Change Default Credits for New Users

Edit `src/index.ts` line 22:

```typescript
const DEFAULT_CREDITS = 500;  // Change to your desired amount
```

Then redeploy:
```bash
npm run deploy
```

### Reset All Beta Users (Nuclear Option)

**WARNING: This deletes all user data!**

```bash
# List all users
npx wrangler kv:key list --namespace-id YOUR_KV_NAMESPACE_ID --prefix "user:"

# Delete each user manually
npx wrangler kv:key delete --namespace-id YOUR_KV_NAMESPACE_ID "user:BETA-TEST-001"
```

---

## Part 7: Troubleshooting

### App shows "Invalid beta proxy URL"

1. Check `SettingsManager.swift` line 1056 has correct URL
2. Rebuild the app
3. Or manually set the URL in Settings (advanced users only)

### Worker returns 401 "Missing beta code"

- Make sure beta code is saved in Settings
- Check that `useBetaAPIProxy` toggle is enabled (automatic when saving beta code)

### Worker returns 402 "Credits exhausted"

- User has used all 500 credits
- App continues working with basic OCR (no LLM enhancement)
- Option: Give user more credits (see Part 6)

### Worker returns 429 "Rate limited"

- User made more than 10 requests in 1 minute
- Wait 60 seconds and try again
- This is a safety feature to prevent abuse

### Credits not updating in app

- Credits update after each successful API call
- Check Settings > AI Enhancement to see current credits
- If stuck, try:
  1. Force quit the app
  2. Reopen and go to Settings
  3. Credits should refresh on next API call

---

## Part 8: Cost Breakdown

### CloudFlare Workers (Free Tier)

- 100,000 requests/day
- 10ms CPU time per request
- KV storage: 1GB free
- **Cost: $0/month** (well within free tier limits)

### Anthropic API Usage

**Per request (typical):**
- Input: ~2,000 tokens @ $3/million = $0.006
- Output: ~500 tokens @ $15/million = $0.0075
- **Total per request: ~$0.0135**

**Per beta tester (1 month):**
- ~150 captures (5/day × 30 days)
- ~75 LLM enhancements (50% usage rate)
- **Total: ~$1.00/tester/month**

**For 25 beta testers:**
- **Total monthly cost: $20-30**
- Each tester's 500 credits = $5.00
- Total allocated: 25 × $5 = $125 worth of credits
- Actual usage: typically 20-30% of allocated

---

## Part 9: Scaling Beyond Beta

When you're ready to launch:

### Option 1: Keep the Proxy (with Payment)

- Add Stripe integration to purchase credits
- Users buy credit packs (100 credits = $1)
- Keep the same infrastructure

### Option 2: Switch to BYOK (Bring Your Own Key)

- Remove beta proxy code
- Users provide their own Anthropic API keys
- Lower costs for you, more flexibility for users

### Option 3: Hybrid Approach

- Free tier: 50 credits/month via proxy
- Power users: BYOK option
- Premium: Subscription with unlimited proxy credits

---

## Need Help?

**CloudFlare Workers Docs:**
https://developers.cloudflare.com/workers/

**Anthropic API Docs:**
https://docs.anthropic.com/

**Check Worker Logs:**
```bash
npm run tail
```

**Test the Worker:**
```bash
curl -X POST https://your-worker-url.workers.dev \
  -H "Content-Type: application/json" \
  -H "X-Beta-Code: BETA-TEST-001" \
  -d '{"model":"claude-sonnet-4-20250514","max_tokens":100,"messages":[{"role":"user","content":"Hi"}]}'
```

Good luck with your beta! 🚀
