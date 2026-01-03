# QuillStack Beta Registration Page

Beautiful, branded beta registration page for quillstack.io that generates instant beta access codes.

## Features

- **Instant Code Generation**: Users get their beta code immediately
- **Shared KV Storage**: Codes work across registration and TestFlight
- **Email Validation**: Prevents duplicates by email
- **QuillStack Branding**: Matches the main site aesthetic
- **Mobile Responsive**: Works perfectly on all devices
- **Zero Configuration**: Just deploy and it works

## Deployment

### Quick Deploy

```bash
cd beta-registration
npm install
npx wrangler pages deploy .
```

This creates a CloudFlare Pages project at: `quillstack-beta-registration.pages.dev`

### Custom Domain

To use your own domain (e.g., `beta.quillstack.io`):

1. Go to CloudFlare Pages dashboard
2. Select your project
3. Go to "Custom domains"
4. Add `beta.quillstack.io`
5. CloudFlare handles SSL automatically

## Integration with quillstack.io

### Option 1: Direct Link (Easiest)

Add a prominent button/link on quillstack.io:

```html
<a href="https://beta.quillstack.io" class="beta-cta">
  Get Beta Access →
</a>
```

### Option 2: Embedded iFrame

Embed the registration form directly on your homepage:

```html
<iframe
  src="https://beta.quillstack.io"
  width="100%"
  height="800"
  frameborder="0"
  style="border-radius: 16px;"
></iframe>
```

### Option 3: Modal/Popup

Use JavaScript to show the registration page in a modal:

```javascript
// Add to your site's main JS
function showBetaRegistration() {
  window.open('https://beta.quillstack.io', 'beta-registration',
    'width=600,height=800,menubar=no,toolbar=no');
}
```

Then trigger with a button:
```html
<button onclick="showBetaRegistration()">
  Join Beta →
</button>
```

## How It Works

1. **User enters email** on the registration page
2. **API generates unique code** using email hash + timestamp
3. **Code stored in CREDITS_KV** (shared namespace with API proxy)
4. **User gets 500 credits** automatically
5. **Code works immediately** in the iOS app

## API Endpoint

**POST /api/register**

Request:
```json
{
  "email": "user@example.com",
  "firstName": "John"
}
```

Response:
```json
{
  "betaCode": "BETA-1234",
  "creditsRemaining": 500,
  "creditsTotal": 500
}
```

Error responses:
- `400`: Invalid email or missing required fields
- `500`: Server error

## Shared KV Namespace

This registration page uses the **same KV namespace** as:
- API Proxy Worker (`quillstack-api-proxy`)
- TestFlight Welcome Worker

**Namespace ID**: `4a21172990624efebb1b2d92af7a0194`

This means:
- ✅ Codes from registration work in the app
- ✅ TestFlight codes work if user also registers
- ✅ No duplicate codes for the same email

## Customization

### Change Default Credits

Edit `functions/api/register.ts` line 105:

```typescript
creditsRemaining: 500,  // Change this value
creditsTotal: 500,      // And this one
```

### Update Branding

Edit `index.html`:
- Colors: Search for `#1e4d2f` and replace
- Logo: Update `.logo` emoji or add `<img>` tag
- Copy: Update text throughout

### Add Analytics

Add to `index.html` before `</head>`:

```html
<!-- Google Analytics -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-XXXXXXXXXX');
</script>
```

## Testing Locally

```bash
npm install
npm run dev
```

Visit: `http://localhost:8788`

Test the form:
1. Enter an email
2. Submit the form
3. Check console logs for generated code
4. Verify code in KV: `npx wrangler kv:key get --namespace-id 4a21172990624efebb1b2d92af7a0194 "user:BETA-XXXX"`

## Monitoring

### View All Registrations

```bash
npx wrangler kv:key list --namespace-id 4a21172990624efebb1b2d92af7a0194 --prefix "user:BETA-"
```

### Check Specific User

```bash
npx wrangler kv:key get --namespace-id 4a21172990624efebb1b2d92af7a0194 "user:BETA-1234"
```

### Registration Stats

Filter by source in KV data:
- `"source": "registration"` = From this page
- `"source": "testflight"` = From TestFlight welcome email

## Security Notes

- ✅ Email validation prevents obviously invalid emails
- ✅ Duplicate detection by email (case-insensitive)
- ✅ CORS headers properly configured
- ✅ No sensitive data in URLs
- ✅ All storage in secure KV namespace

## Support

Questions? Email support@quillstack.io or check the main QuillStack docs.
