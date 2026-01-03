# QuillStack Beta System - Complete Integration Guide

This guide covers the complete beta access system, including the registration page, TestFlight welcome emails, and API proxy.

## System Overview

You now have a **hybrid beta access system** with three components that share a single KV namespace:

1. **Beta Registration Page** - Public form on quillstack.io
2. **TestFlight Welcome Worker** - Auto-emails new TestFlight users
3. **API Proxy Worker** - Handles Claude API calls with credits

All three systems share the same `CREDITS_KV` namespace (ID: `4a21172990624efebb1b2d92af7a0194`), so beta codes work across all entry points.

---

## Part 1: Deploy the Registration Page

### 1. Install Dependencies

```bash
cd beta-registration
npm install
```

### 2. Deploy to CloudFlare Pages

```bash
npx wrangler pages deploy .
```

**Output:** You'll get a URL like `https://quillstack-beta-registration.pages.dev`

### 3. Set Up Custom Domain (Optional but Recommended)

1. Go to [CloudFlare Pages Dashboard](https://dash.cloudflare.com/pages)
2. Select `quillstack-beta-registration`
3. Click "Custom domains"
4. Add `beta.quillstack.io` (or your preferred subdomain)
5. CloudFlare auto-configures DNS and SSL

**Result:** Your registration page is live at `https://beta.quillstack.io`

---

## Part 2: Update TestFlight Welcome Worker

The welcome worker has been updated to:
- Generate unique beta codes for each tester
- Store codes in shared KV namespace
- Include codes prominently in welcome emails

### 1. Redeploy the Worker

```bash
cd testflight-welcome-worker
npx wrangler deploy
```

### 2. Verify Configuration

Check that `wrangler.toml` includes both KV namespaces:

```toml
[[kv_namespaces]]
binding = "SENT_EMAILS"
id = "22aa30bbc14548bda301cdb0961a136f"

[[kv_namespaces]]
binding = "CREDITS_KV"
id = "4a21172990624efebb1b2d92af7a0194"
```

### 3. Test the Worker

Trigger manually:
```bash
cd testflight-welcome-worker
./trigger.sh
```

Or wait for the next scheduled run (every 15 minutes).

---

## Part 3: Integrate with quillstack.io

Choose one of these integration methods:

### Option A: Hero Section CTA (Recommended)

Add a prominent call-to-action in your hero section:

```html
<!-- In your homepage hero section -->
<div class="hero">
  <h1>QuillStack</h1>
  <p>Transform Handwriting Into Action</p>

  <div class="cta-buttons">
    <a href="https://beta.quillstack.io" class="btn-primary">
      Get Beta Access →
    </a>
    <a href="/features" class="btn-secondary">
      Learn More
    </a>
  </div>
</div>

<style>
  .btn-primary {
    background: linear-gradient(135deg, #1e4d2f 0%, #143d23 100%);
    color: white;
    padding: 16px 32px;
    border-radius: 10px;
    font-weight: 600;
    text-decoration: none;
    box-shadow: 0 4px 12px rgba(30, 77, 47, 0.25);
  }

  .btn-primary:hover {
    transform: translateY(-2px);
    box-shadow: 0 6px 16px rgba(30, 77, 47, 0.35);
  }
</style>
```

### Option B: Sticky Header Banner

Add a beta announcement banner:

```html
<!-- At top of page -->
<div class="beta-banner">
  <span>🎉 QuillStack Beta is now open!</span>
  <a href="https://beta.quillstack.io">Get Instant Access →</a>
</div>

<style>
  .beta-banner {
    background: linear-gradient(135deg, #1e4d2f 0%, #143d23 100%);
    color: white;
    padding: 12px 20px;
    text-align: center;
    position: sticky;
    top: 0;
    z-index: 1000;
    font-size: 15px;
  }

  .beta-banner a {
    color: #e8f0e8;
    text-decoration: underline;
    font-weight: 600;
    margin-left: 12px;
  }
</style>
```

### Option C: Modal Popup (For Maximum Conversion)

```html
<!-- Add to your site -->
<div id="beta-modal" class="modal" style="display: none;">
  <div class="modal-content">
    <span class="close">&times;</span>
    <iframe
      src="https://beta.quillstack.io"
      width="100%"
      height="700px"
      frameborder="0"
      style="border-radius: 12px;"
    ></iframe>
  </div>
</div>

<script>
  // Show modal after 5 seconds
  setTimeout(() => {
    const modal = document.getElementById('beta-modal');
    modal.style.display = 'block';

    // Close on click outside or X button
    const close = document.querySelector('.close');
    close.onclick = () => modal.style.display = 'none';
    window.onclick = (e) => {
      if (e.target == modal) modal.style.display = 'none';
    };
  }, 5000);
</script>

<style>
  .modal {
    position: fixed;
    z-index: 9999;
    left: 0;
    top: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.6);
    backdrop-filter: blur(4px);
  }

  .modal-content {
    background: white;
    margin: 5% auto;
    padding: 0;
    width: 90%;
    max-width: 600px;
    border-radius: 16px;
    position: relative;
  }

  .close {
    position: absolute;
    right: 20px;
    top: 10px;
    font-size: 32px;
    font-weight: bold;
    color: #aaa;
    cursor: pointer;
    z-index: 1;
  }

  .close:hover {
    color: #000;
  }
</style>
```

---

## Part 4: How It All Works Together

### User Journey 1: Website Registration

1. User visits `https://beta.quillstack.io`
2. Enters email and optional first name
3. API generates unique code: `BETA-1234`
4. Code stored in `CREDITS_KV` with 500 credits
5. User sees code instantly on success screen
6. User downloads TestFlight and enters code in app

### User Journey 2: TestFlight Direct

1. User joins TestFlight directly
2. Welcome worker runs every 15 minutes
3. Detects new tester, generates code: `BETA-5678`
4. Code stored in `CREDITS_KV` with 500 credits
5. Welcome email sent with code prominently displayed
6. User enters code in app

### User Journey 3: Both (Registration + TestFlight)

1. User registers on website → gets `BETA-1234`
2. Later joins TestFlight → welcome worker checks email
3. **Email already exists** → returns existing `BETA-1234`
4. User receives welcome email with same code
5. No duplicate credits, seamless experience

### In the iOS App

All three entry points lead to the same experience:

1. User opens Settings → AI Enhancement
2. Enters beta code (e.g., `BETA-1234`)
3. App calls API proxy: `https://quillstack-api-proxy.mikebmott.workers.dev`
4. Proxy checks `CREDITS_KV` for `user:BETA-1234`
5. **Found!** → Returns credits info in headers
6. App unlocks AI features and shows 500 credits
7. Each API call deducts credits automatically

---

## Part 5: Monitoring & Analytics

### View All Beta Users

```bash
npx wrangler kv:key list --namespace-id 4a21172990624efebb1b2d92af7a0194 --prefix "user:"
```

### Check Registration vs TestFlight

Filter by source:
```bash
# Get user data
npx wrangler kv:key get --namespace-id 4a21172990624efebb1b2d92af7a0194 "user:BETA-1234"

# Check the "source" field:
# "source": "registration" = From website
# "source": "testflight" = From TestFlight
```

### Track Credit Usage

Each beta user record includes:
- `creditsRemaining`: Current balance
- `creditsTotal`: Original allocation (500)
- `requestCount`: Number of API calls made
- `lastUsedAt`: Last activity timestamp

### Export All Data

```bash
# List all user keys
npx wrangler kv:key list --namespace-id 4a21172990624efebb1b2d92af7a0194 \
  --prefix "user:" > beta-users.json
```

---

## Part 6: Customization

### Change Default Credits

**Registration Page:** Edit `beta-registration/functions/api/register.ts`:
```typescript
creditsRemaining: 500,  // Change this
creditsTotal: 500,      // And this
```

**TestFlight Worker:** Edit `testflight-welcome-worker/src/index.ts`:
```typescript
creditsRemaining: 500,  // Line 152
creditsTotal: 500,      // Line 153
```

Then redeploy both:
```bash
cd beta-registration && npx wrangler pages deploy .
cd ../testflight-welcome-worker && npx wrangler deploy
```

### Customize Email Template

Edit `testflight-welcome-worker/src/emailTemplate.ts`:
- Update hero section (line 239-242)
- Modify beta code display (line 256-263)
- Change features list (line 265-358)
- Update get started steps (line 361-367)

Redeploy:
```bash
cd testflight-welcome-worker
npx wrangler deploy
```

### Customize Registration Page Branding

Edit `beta-registration/index.html`:
- **Colors:** Search/replace `#1e4d2f` (forest green)
- **Logo:** Update line 244 emoji or add `<img>`
- **Copy:** Update headlines and descriptions throughout

Redeploy:
```bash
cd beta-registration
npx wrangler pages deploy .
```

---

## Part 7: Testing End-to-End

### Test Registration Flow

1. Visit your beta page: `https://beta.quillstack.io`
2. Enter a test email: `test+beta1@example.com`
3. Submit form
4. **Verify:** You get a code like `BETA-1234`
5. **Check KV:**
   ```bash
   npx wrangler kv:key get --namespace-id 4a21172990624efebb1b2d92af7a0194 "user:BETA-1234"
   ```
6. **Should see:** User record with `"source": "registration"`

### Test TestFlight Flow

1. Add yourself to TestFlight
2. Wait for welcome worker (runs every 15 minutes) OR trigger manually:
   ```bash
   cd testflight-welcome-worker
   ./trigger.sh
   ```
3. **Verify:** Check your email for welcome message with beta code
4. **Check KV:**
   ```bash
   npx wrangler kv:key get --namespace-id 4a21172990624efebb1b2d92af7a0194 "user:BETA-XXXX"
   ```
5. **Should see:** User record with `"source": "testflight"`

### Test iOS App

1. Build and run QuillStack
2. Go to Settings → AI Enhancement
3. Enter your beta code
4. **Verify:** Credits display shows "500 of 500 credits remaining"
5. Take a photo with `#todo#` tag
6. **Verify:** Text is auto-enhanced
7. **Check credits:** Should decrease slightly

---

## Part 8: Launch Checklist

Before going live with your beta:

- [ ] Registration page deployed to custom domain
- [ ] TestFlight welcome worker running (check logs)
- [ ] API proxy worker tested with sample beta code
- [ ] quillstack.io updated with registration CTA
- [ ] Email template tested and branded
- [ ] iOS app updated with proxy URL
- [ ] Test registration flow end-to-end
- [ ] Test TestFlight flow end-to-end
- [ ] Test iOS app with beta code
- [ ] Monitor KV storage for first few registrations
- [ ] Set up analytics (optional)

---

## Part 9: Support & Troubleshooting

### Registration Page Shows Error

**Check:**
1. KV namespace binding is correct in `wrangler.toml`
2. API endpoint is accessible: `curl -X POST https://beta.quillstack.io/api/register -d '{"email":"test@test.com"}'`
3. CORS headers are set (check browser console)

### Welcome Emails Not Sending

**Check:**
1. Worker is deployed: `cd testflight-welcome-worker && npx wrangler tail`
2. CREDITS_KV binding exists in `wrangler.toml`
3. Trigger manually to test: `./trigger.sh`
4. Check worker logs for errors

### iOS App Can't Use Beta Code

**Check:**
1. Settings → betaAPIProxyURL is set correctly
2. Beta code exists in KV: `npx wrangler kv:key get ...`
3. API proxy worker is deployed and accessible
4. Credits > 0 in user record

---

## Part 10: Analytics & Growth

### Track Registration Sources

Add UTM parameters to your CTAs:

```html
<a href="https://beta.quillstack.io?utm_source=homepage&utm_medium=hero">
  Get Beta Access →
</a>
```

Then in `functions/api/register.ts`, log the source:
```typescript
const url = new URL(context.request.url);
const utm_source = url.searchParams.get('utm_source');
console.log('Registration from:', utm_source);
```

### A/B Test CTAs

Try different button copy:
- "Get Beta Access" vs "Join Beta" vs "Try QuillStack"
- Track which converts better via UTM parameters

### Monitor Conversion Rate

Track:
1. **Page visits:** CloudFlare Pages analytics
2. **Form submissions:** Count KV records with `source: "registration"`
3. **App activations:** Count users with `requestCount > 0`

---

## Questions?

- **Technical issues:** Check worker logs with `npx wrangler tail`
- **KV questions:** See `api-proxy-worker/README.md`
- **Email template:** See `testflight-welcome-worker/README.md`
- **Registration page:** See `beta-registration/README.md`

Happy beta launching! 🚀
