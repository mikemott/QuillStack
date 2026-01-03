#!/bin/bash

# Test the TestFlight welcome email worker
# This will check for new beta testers and send emails

WORKER_URL="https://testflight-welcome-worker.mikebmott.workers.dev"

# Get the RESEND_API_KEY from wrangler secrets
echo "🧪 Testing TestFlight welcome email worker..."
echo ""
echo "⚠️  You need to provide your RESEND_API_KEY as a Bearer token"
echo ""
read -p "Enter your RESEND_API_KEY: " API_KEY

echo ""
echo "📡 Triggering worker at $WORKER_URL..."
echo ""

curl -X GET "$WORKER_URL" \
  -H "Authorization: Bearer $API_KEY" \
  -v

echo ""
echo ""
echo "✅ Check the Cloudflare dashboard for logs:"
echo "   https://dash.cloudflare.com/workers"
