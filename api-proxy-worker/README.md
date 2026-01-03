# QuillStack API Proxy Worker

CloudFlare Worker that proxies Anthropic API requests for QuillStack beta testers with built-in credits tracking and rate limiting.

## Features

- **Credits System**: Each beta tester gets 500 credits ($5.00 worth)
- **Usage Tracking**: Automatically tracks token usage and deducts credits
- **Rate Limiting**: Maximum 10 requests per minute per user
- **Analytics**: Stores usage stats for 30 days
- **Graceful Degradation**: App continues working when credits run out (non-LLM mode)
- **CORS Support**: Works with iOS app

## Setup Instructions

### 1. Install Dependencies

```bash
cd api-proxy-worker
npm install
```

### 2. Login to CloudFlare

```bash
npx wrangler login
```

### 3. Create KV Namespace

```bash
npx wrangler kv:namespace create CREDITS_KV
```

This will output a namespace ID like:
```
{ binding = "CREDITS_KV", id = "abc123..." }
```

Copy the `id` and update `wrangler.toml`:
```toml
[[kv_namespaces]]
binding = "CREDITS_KV"
id = "abc123..."  # Replace with your actual ID
```

### 4. Set Your Anthropic API Key

```bash
npx wrangler secret put ANTHROPIC_API_KEY
```

When prompted, paste your Anthropic API key.

### 5. Deploy to CloudFlare

```bash
npm run deploy
```

This will output a URL like: `https://quillstack-api-proxy.your-subdomain.workers.dev`

Copy this URL - you'll need it for the iOS app configuration.

## Usage

### Testing the Worker

```bash
curl -X POST https://quillstack-api-proxy.your-subdomain.workers.dev \
  -H "Content-Type: application/json" \
  -H "X-Beta-Code: BETA-TEST-001" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "max_tokens": 100,
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### Checking Credits

Credits info is returned in response headers:
- `X-Credits-Remaining`: Credits left
- `X-Credits-Used`: Credits used for this request
- `X-Credits-Total`: Total credits allocated

### Beta Codes

Beta codes can be any string. When a new beta code is used, the system automatically:
1. Creates a user record
2. Allocates 500 credits (DEFAULT_CREDITS in index.ts)
3. Starts tracking usage

Example beta codes for testing:
- `BETA-TEST-001`
- `BETA-TEST-002`
- etc.

## Cost Management

### Current Pricing (as of index.ts)
- **Input tokens**: $3 per million tokens
- **Output tokens**: $15 per million tokens
- **Default credits**: 500 ($5.00 worth)

### Estimated Usage (per beta tester per month)
- ~150 captures (5/day × 30 days)
- ~75 LLM enhancements (50% usage rate)
- ~2000 input tokens + 500 output tokens per request
- **Total cost**: ~$0.15-$0.30/user/month

### For 25 beta testers
- **Monthly cost**: $3.75-$7.50
- **Credits needed**: 25 × 500 = 12,500 credits

## Modifying Credits

To change the default credits per user, edit `src/index.ts`:

```typescript
const DEFAULT_CREDITS = 500;  // Change this value
```

Then redeploy:
```bash
npm run deploy
```

## Monitoring

### View Logs
```bash
npm run tail
```

### Check KV Storage (Beta Users)
```bash
npx wrangler kv:key list --namespace-id YOUR_KV_NAMESPACE_ID --prefix "user:"
```

### Check Usage Stats
```bash
npx wrangler kv:key list --namespace-id YOUR_KV_NAMESPACE_ID --prefix "stats:"
```

### Get Specific User Info
```bash
npx wrangler kv:key get --namespace-id YOUR_KV_NAMESPACE_ID "user:BETA-TEST-001"
```

## Manually Adding/Modifying Credits

To give a specific user more credits:

```bash
npx wrangler kv:key put --namespace-id YOUR_KV_NAMESPACE_ID "user:BETA-TEST-001" \
  '{"betaCode":"BETA-TEST-001","creditsRemaining":1000,"creditsTotal":1000,"createdAt":"2026-01-02T00:00:00Z","lastUsedAt":"2026-01-02T00:00:00Z","requestCount":0}'
```

## Rate Limiting

Current limit: 10 requests per minute per beta code.

To modify, edit `src/index.ts`:
```typescript
const MAX_REQUESTS_PER_MINUTE = 10;  // Change this value
```

## Error Responses

### 401 - Missing Beta Code
```json
{
  "error": "Missing beta code",
  "message": "Please enter your beta code in Settings to use AI features."
}
```

### 402 - Credits Exhausted
```json
{
  "error": "Credits exhausted",
  "message": "Your beta credits have been used up. The app will continue to work with basic OCR.",
  "creditsRemaining": 0,
  "creditsTotal": 500
}
```

### 429 - Rate Limited
```json
{
  "error": "Rate limited",
  "message": "Too many requests. Please wait a minute and try again."
}
```

## Security Notes

- API key is stored as a CloudFlare secret (not in code)
- CORS is enabled for all origins (restrict in production if needed)
- Rate limiting prevents abuse
- Credits prevent runaway costs

## Next Steps

1. Deploy the worker (see Setup above)
2. Update iOS app to use the worker URL
3. Generate beta codes for testers
4. Monitor usage via CloudFlare dashboard
