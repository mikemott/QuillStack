#!/bin/bash
# Auto-fix PR-Agent feedback
# Usage: ./bin/auto-fix-pr-feedback.sh <PR_NUMBER>

set -e

PR_NUMBER=$1
if [ -z "$PR_NUMBER" ]; then
    echo "Usage: $0 <PR_NUMBER>"
    exit 1
fi

echo "⏳ Waiting for PR-Agent to complete review of PR #$PR_NUMBER..."

# Wait for PR-Agent to finish (max 5 minutes)
MAX_WAIT=300
ELAPSED=0
INTERVAL=10

while [ $ELAPSED -lt $MAX_WAIT ]; do
    # Check if PR-Agent has completed
    STATUS=$(gh pr checks $PR_NUMBER --json name,status,conclusion -q '.[] | select(.name == "Run PR Agent") | .status')

    if [ "$STATUS" = "COMPLETED" ]; then
        echo "✅ PR-Agent review complete"
        break
    fi

    echo "   Still running... ($ELAPSED/${MAX_WAIT}s)"
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo "⏱️  Timeout waiting for PR-Agent"
    exit 1
fi

# Trigger Claude Code to review and fix
echo "🤖 Analyzing PR-Agent feedback..."
echo ""
echo "Please review the PR-Agent feedback and apply fixes:"
echo "  claude pr-fix $PR_NUMBER"
echo ""
echo "Or paste this prompt to Claude Code:"
echo "---"
echo "Can you take a look at the PR Agent's feedback and see if any changes need to be made?"
echo "---"
