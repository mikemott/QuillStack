# Linear MCP Server Setup for Cursor

This guide will help you set up the Linear MCP (Model Context Protocol) server so that Claude can access your Linear issues directly.

## Quick Setup (Recommended)

### Step 1: Open Cursor Settings
1. Press `CMD + Shift + J` (or `CTRL + Shift + J` on Windows/Linux)
2. This opens Cursor Settings

### Step 2: Navigate to MCP Section
1. In the settings sidebar, look for **"MCP"** or **"Model Context Protocol"**
2. Click on it to expand the MCP settings

### Step 3: Add Linear MCP Server
1. Click **"Add new global MCP server"** or **"Add Server"**
2. You'll be prompted to enter server configuration

### Step 4: Enter Configuration
Add the following JSON configuration:

```json
{
  "mcpServers": {
    "linear": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.linear.app/mcp"]
    }
  }
}
```

**Or if the UI asks for individual fields:**
- **Server Name:** `linear`
- **Command:** `npx`
- **Args:** `-y`, `mcp-remote`, `https://mcp.linear.app/mcp`

### Step 5: Save and Restart
1. Save the configuration
2. Restart Cursor to activate the MCP server
3. The first time you use it, you'll be prompted to authenticate with Linear

## Authentication

When you first use the Linear MCP server, you'll be prompted to:
1. Authenticate with your Linear account
2. Grant permissions for the MCP server to access your Linear workspace
3. This is a one-time setup

## Verification

After setup, you can verify it's working by asking me:
- "Can you fetch Linear issue QUI-142?"
- "Show me all open Linear issues"
- "What's the status of QUI-143?"

## Alternative: Manual Config File (If UI doesn't work)

If the UI method doesn't work, you can manually edit the config file:

1. **Find Cursor's config file location:**
   - macOS: `~/Library/Application Support/Cursor/User/globalStorage/mcp.json`
   - Or check: `~/.cursor/mcp.json`

2. **Create or edit the file** with:
   ```json
   {
     "mcpServers": {
       "linear": {
         "command": "npx",
         "args": ["-y", "mcp-remote", "https://mcp.linear.app/mcp"]
       }
     }
   }
   ```

3. **Restart Cursor**

## Troubleshooting

### Issue: "npx not found"
**Solution:** Make sure Node.js is installed:
```bash
# Check if Node.js is installed
node --version

# If not installed, install via Homebrew:
brew install node
```

### Issue: "Authentication failed"
**Solution:** Clear saved auth and try again:
```bash
rm -rf ~/.mcp-auth
```
Then restart Cursor and authenticate again.

### Issue: "Internal Server Error"
**Solution:** 
1. Clear auth cache: `rm -rf ~/.mcp-auth`
2. Check your internet connection
3. Verify Linear's MCP server is accessible: `curl https://mcp.linear.app/mcp`

### Issue: MCP section not visible in settings
**Solution:**
- Make sure you're using a recent version of Cursor
- MCP support may require Cursor version 0.40+ or later
- Check for updates: `Cursor > Check for Updates`

## What This Enables

Once set up, I'll be able to:
- ✅ Fetch Linear issues by ID (e.g., QUI-142, QUI-143)
- ✅ Search Linear issues by title, description, or labels
- ✅ Read issue details, comments, and status
- ✅ View issue relationships and dependencies
- ✅ Access team and project information

## Next Steps

After setup, you can ask me to:
1. Review QUI-142-146 and add context
2. Fetch any Linear issue details
3. Search for issues matching criteria
4. Analyze issue relationships

---

**Reference:** [Linear MCP Documentation](https://linear.app/docs/mcp)


