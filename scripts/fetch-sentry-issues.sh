#!/bin/bash
# Fetch Sentry performance issues for Cursor review
# Usage: ./scripts/fetch-sentry-issues.sh

# Set your Sentry credentials
SENTRY_TOKEN="${SENTRY_AUTH_TOKEN:-your-auth-token}"
ORG="${SENTRY_ORG:-your-org}"
PROJECT="${SENTRY_PROJECT:-quillstack}"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Fetching Sentry performance issues...${NC}"

# Fetch slow transactions (>1 second)
curl -s -H "Authorization: Bearer $SENTRY_TOKEN" \
  -H "Content-Type: application/json" \
  "https://sentry.io/api/0/organizations/$ORG/events/?project=$PROJECT&query=transaction.duration:>1000&statsPeriod=7d" \
  > /tmp/sentry-performance-issues.json

# Check if we got data
if [ ! -s /tmp/sentry-performance-issues.json ]; then
    echo "No performance issues found or API error. Check your credentials."
    exit 1
fi

# Format for Cursor
echo -e "${GREEN}Formatting issues for Cursor...${NC}"
cat > sentry-issues-for-cursor.md << 'EOF'
# Sentry Performance Issues for Cursor Review

Generated: $(date)

## Slow Transactions (>1 second)

EOF

# Extract and format issues
jq -r '.[] | 
"### Transaction: \(.transaction // "Unknown")
- **Duration**: \(.measurements.duration.value // 0)ms
- **URL**: \(.permalink // "N/A")
- **Device**: \(.contexts.device.model // "Unknown") - \(.contexts.os.name // "Unknown") \(.contexts.os.version // "")
- **App Version**: \(.release // "Unknown")
- **Timestamp**: \(.timestamp)

**Slow Spans:**
\(.spans // [] | map("  - \(.op): \(.duration)ms") | join("\n"))

---
"' /tmp/sentry-performance-issues.json >> sentry-issues-for-cursor.md

echo -e "${GREEN}✅ Issues saved to: sentry-issues-for-cursor.md${NC}"
echo -e "${BLUE}Share this file with Cursor to review and fix performance issues.${NC}"

# Also create a summary
echo -e "\n${BLUE}Summary:${NC}"
jq -r '.[] | "\(.transaction // "Unknown"): \(.measurements.duration.value // 0)ms"' /tmp/sentry-performance-issues.json | head -10

