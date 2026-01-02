# TestFlight Welcome Email Worker

Cloudflare Worker that automatically sends personalized welcome emails to new QuillStack TestFlight beta testers.

## Overview

This serverless worker runs every 15 minutes to:
1. 📱 Fetch accepted TestFlight beta testers via App Store Connect API
2. 🔍 Check which testers haven't received welcome emails yet
3. 📧 Send personalized welcome emails via Resend
4. ✅ Track sent emails in Cloudflare KV to prevent duplicates

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    CLOUDFLARE WORKERS                        │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │ Cron (15min) │───▶│   Worker     │───▶│ Cloudflare KV│   │
│  └──────────────┘    └──────┬───────┘    │ (sent log)   │   │
│                             │            └──────────────┘   │
└─────────────────────────────┼───────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
    ┌──────────────────┐           ┌──────────────────┐
    │ App Store Connect│           │     Resend       │
    │ API (testers)    │           │ (send email)     │
    └──────────────────┘           └──────────────────┘
```

## Prerequisites

- [x] Apple Developer account with App Store Connect access
- [x] Cloudflare account (free tier works)
- [x] Resend account (free tier: 3,000 emails/month forever)
- [x] Domain for sending emails (recommended for deliverability)
- [x] Node.js 18+ installed locally

## Setup Instructions

### Step 1: Create App Store Connect API Key

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to **Users and Access** → **Keys** → **App Store Connect API**
3. Click **+** to create a new key
4. Name it "TestFlight Welcome Emails"
5. Grant **Admin** or **Developer** role (needs beta tester read access)
6. Download the `.p8` private key file (**only downloadable once!**)
7. Note the **Key ID** displayed
8. Note the **Issuer ID** at the top of the keys page

### Step 2: Get Your App's ID

1. In App Store Connect, go to **My Apps**
2. Select QuillStack
3. The App ID is in **App Information** (e.g., `123456789`)

### Step 3: Set Up Resend

1. Create account at [resend.com](https://resend.com)
2. Add your sending domain (e.g., `quillstack.app`)
3. Add the required DNS records to your domain:
   - **MX record**: `feedback.us1.resend.email`
   - **TXT record** for SPF: `v=spf1 include:amazonses.com ~all`
   - **DKIM records** (provided by Resend)
4. Wait for verification (usually 5-30 minutes)
5. Copy your **API Key** from API Keys page

### Step 4: Set Up Cloudflare Workers

#### Install Wrangler CLI

```bash
npm install -g wrangler
```

#### Login to Cloudflare

```bash
wrangler login
```

#### Install Dependencies

```bash
cd testflight-welcome-worker
npm install
```

#### Create KV Namespace

```bash
wrangler kv:namespace create SENT_EMAILS
```

This will output something like:
```
🌀 Creating namespace with title "testflight-welcome-worker-SENT_EMAILS"
✨ Success!
Add the following to your wrangler.toml:
[[kv_namespaces]]
binding = "SENT_EMAILS"
id = "abc123def456..."
```

Copy the `id` value and update `wrangler.toml`:

```toml
[[kv_namespaces]]
binding = "SENT_EMAILS"
id = "abc123def456..."  # Replace with your actual ID
```

#### Update Configuration

Edit `wrangler.toml` and update:

```toml
[vars]
APP_STORE_APP_ID = "123456789"  # Your App ID from Step 2
RESEND_DOMAIN = "quillstack.app"  # Your verified domain
FROM_EMAIL = "hello@quillstack.app"
FROM_NAME = "QuillStack Team"
```

### Step 5: Configure Secrets

Set your secrets via Wrangler CLI:

```bash
# App Store Connect credentials
wrangler secret put APP_STORE_ISSUER_ID
# Paste your Issuer ID when prompted

wrangler secret put APP_STORE_KEY_ID
# Paste your Key ID when prompted

wrangler secret put APP_STORE_PRIVATE_KEY
# Paste the ENTIRE contents of your .p8 file, including:
# -----BEGIN PRIVATE KEY-----
# [key contents]
# -----END PRIVATE KEY-----

# Resend API key
wrangler secret put RESEND_API_KEY
# Paste your Resend API key when prompted
```

### Step 6: Deploy

```bash
wrangler deploy
```

This will output your worker URL, e.g.:
```
https://testflight-welcome-worker.your-subdomain.workers.dev
```

### Step 7: Test

#### View Logs

```bash
wrangler tail
```

#### Manual Trigger (Optional)

Trigger the worker manually without waiting for the cron:

```bash
curl -X POST https://testflight-welcome-worker.your-subdomain.workers.dev \
  -H "Authorization: Bearer YOUR_RESEND_API_KEY"
```

#### Check Results

1. **Cloudflare Dashboard**: View worker logs and analytics
2. **Resend Dashboard**: View sent emails and delivery status
3. **Check your inbox**: Add yourself as a TestFlight tester to receive the welcome email

## File Structure

```
testflight-welcome-worker/
├── wrangler.toml              # Cloudflare Worker configuration
├── package.json               # Node dependencies
├── tsconfig.json             # TypeScript configuration
├── README.md                 # This file
└── src/
    ├── index.ts              # Main worker entry point
    ├── jwt.ts                # JWT generation for Apple API
    ├── appStoreConnect.ts    # App Store Connect API client
    ├── resend.ts             # Resend email sender
    └── emailTemplate.ts      # HTML and text email templates
```

## How It Works

### Cron Schedule

The worker runs **every 15 minutes** via Cloudflare's cron triggers:

```toml
[triggers]
crons = ["*/15 * * * *"]
```

### Email Deduplication

Each tester's ID is stored in Cloudflare KV after sending their welcome email. The worker checks KV before sending to prevent duplicate emails.

**KV Record Structure:**
```json
{
  "email": "tester@example.com",
  "sentAt": "2024-01-15T10:30:00Z"
}
```

Records expire after 1 year.

### Personalization

Emails are personalized using the tester's first name from App Store Connect:

```typescript
const firstName = tester.firstName || 'there';
```

## Email Template

The welcome email includes:
- Personalized greeting
- Brief intro to QuillStack
- 3 quick-start tips (capture, hashtags, editing)
- Feedback CTA button
- Brand styling (forest greens, paper tones)
- Plain text fallback for accessibility

To customize the email, edit `src/emailTemplate.ts`.

## Monitoring

### View Logs

```bash
wrangler tail
```

### Check Email Delivery

Visit the Resend dashboard to view:
- Delivery status
- Open rates
- Click rates
- Bounce rates

### Cloudflare Analytics

View worker analytics in the Cloudflare dashboard:
- Request count
- CPU time
- Errors

## Cost

All services used are **free tier**:

| Service | Free Tier | Expected Usage | Monthly Cost |
|---------|-----------|----------------|--------------|
| Cloudflare Workers | 100K requests/day | ~3K requests/month | **$0** |
| Cloudflare KV | 100K reads, 1K writes/day | Minimal | **$0** |
| Resend | 3K emails/month forever | <100 emails/month | **$0** |
| App Store Connect API | Unlimited | ~3K requests/month | **$0** |

**Total: $0/month** for typical beta testing scale

## Troubleshooting

### Worker Not Running

Check Cloudflare dashboard for errors. View logs with:
```bash
wrangler tail
```

### Emails Not Sending

1. Verify Resend domain is verified
2. Check Resend API key is correct
3. View Resend dashboard for delivery errors
4. Check spam folder

### App Store Connect Errors

1. Verify API key has correct permissions
2. Check JWT is being generated correctly
3. Ensure App ID is correct
4. Verify private key includes full PEM format

### Duplicate Emails

If testers receive multiple emails:
1. Check KV namespace is created and bound correctly
2. Verify tester IDs are being stored
3. View KV browser in Cloudflare dashboard

## Development

### Run Locally

```bash
npm run dev
```

This starts a local development server with hot reloading.

### Type Checking

TypeScript is configured for strict type checking. The worker uses:
- ES2021 target
- Cloudflare Workers types
- Strict mode enabled

## Future Enhancements

- [ ] Segmented emails for internal vs external testers
- [ ] Follow-up email sequence (Day 3, Day 7)
- [ ] Feedback collection form integration
- [ ] A/B testing different subject lines
- [ ] Build notifications (email when new builds available)
- [ ] Slack notifications for new signups

## License

MIT

## Support

For issues or questions:
- Email: feedback@quillstack.app
- File an issue in the QuillStack repository
