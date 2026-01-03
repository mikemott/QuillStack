# Setting Up Sentry API Key with Proper Permissions

This guide walks you through creating a Sentry API key that can access issues, performance data, and other Sentry resources.

---

## Step-by-Step Instructions

### Step 1: Navigate to API Tokens

1. Go to [Sentry.io](https://sentry.io) and sign in
2. Click on your **profile icon** (top right)
3. Select **User Settings**
4. In the left sidebar, click **Auth Tokens**
5. Or go directly to: https://sentry.io/settings/account/api/auth-tokens/

### Step 2: Create New Token

1. Click the **"Create New Token"** button
2. Give it a descriptive name: `Cursor Integration` or `QuillStack Development`
3. **Select Scopes** - This is the important part!

### Step 3: Select Required Scopes

For full access to issues and performance data, select these scopes:

#### Required Scopes:
- ✅ **`org:read`** - Read organization information
- ✅ **`project:read`** - Read project information
- ✅ **`event:read`** - Read events and issues
- ✅ **`event:write`** - Write events (for creating test events)
- ✅ **`project:releases`** - Read release information

#### Optional but Recommended:
- ✅ **`org:read`** - Already listed above
- ✅ **`member:read`** - Read team member information

#### For Performance Data:
- ✅ **`project:read`** - Already listed above
- ✅ **`event:read`** - Already listed above

**Note:** Sentry's scope names may vary slightly. Look for:
- Read access to issues/events
- Read access to projects
- Read access to organization

### Step 4: Create and Copy Token

1. Click **"Create Token"**
2. **⚠️ IMPORTANT:** Copy the token immediately - you won't be able to see it again!
3. The token will look like: `sntrys_...` (long string)

### Step 5: Store Token Securely

**Option A: Store in project (gitignored)**
```bash
# In your project directory
echo "YOUR_TOKEN_HERE" > .sentry-api-key
chmod 600 .sentry-api-key
echo ".sentry-api-key" >> .gitignore
```

**Option B: Store as environment variable**
```bash
# Add to your shell profile (~/.zshrc or ~/.bashrc)
export SENTRY_AUTH_TOKEN="YOUR_TOKEN_HERE"
```

---

## Testing Your API Key

Once you have the token, test it:

```bash
# Test basic access
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "https://sentry.io/api/0/organizations/quillstack-7z/projects/"

# Test issue access
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "https://sentry.io/api/0/issues/7161938631/"
```

If you get data back (not permission errors), you're good!

---

## Updating the Existing Key

If you want to update the key we stored earlier:

```bash
# Replace the existing key
echo "YOUR_NEW_TOKEN" > .sentry-api-key
chmod 600 .sentry-api-key
```

---

## Troubleshooting

### "You do not have permission" Error

**Cause:** Missing required scopes

**Solution:**
1. Go back to Auth Tokens
2. Edit your token (or create new one)
3. Make sure you selected:
   - `event:read` (for reading issues)
   - `project:read` (for reading project data)
   - `org:read` (for organization access)

### Token Not Working

**Check:**
1. Did you copy the full token? (they're long)
2. Are you using `Bearer` in the Authorization header?
3. Is the token still active? (check Sentry → Auth Tokens)

### Can't Find Scopes

**Sentry UI may show:**
- Checkboxes for permissions
- A list of scopes to select
- Or a "Permissions" dropdown

Look for anything related to:
- Reading events/issues
- Reading projects
- Reading organization data

---

## Security Best Practices

1. **Don't commit tokens to git** - Always use `.gitignore`
2. **Use least privilege** - Only select scopes you need
3. **Rotate tokens** - Create new ones periodically
4. **Revoke unused tokens** - Delete old/unused tokens
5. **Use different tokens** - One for development, one for production (if needed)

---

## Quick Reference

**Sentry Auth Tokens URL:**
https://sentry.io/settings/account/api/auth-tokens/

**Required Scopes:**
- `org:read`
- `project:read`
- `event:read`
- `event:write` (optional, for testing)

**Test Command:**
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "https://sentry.io/api/0/organizations/quillstack-7z/projects/"
```

---

Once you have the new token with proper permissions, share it and I'll:
1. Update the stored key
2. Test access to the issue
3. Analyze the Sentry issue you mentioned

