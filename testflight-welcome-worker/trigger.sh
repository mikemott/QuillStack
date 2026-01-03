#!/bin/bash

# Trigger the TestFlight welcome email worker
# This will check for new beta testers and send welcome emails

echo "🚀 Triggering TestFlight welcome email worker..."
echo ""
echo "⚠️  Please enter your RESEND_API_KEY (starts with re_)"
echo "   (You can find it at https://resend.com/api-keys)"
echo ""
read -sp "RESEND_API_KEY: " API_KEY
echo ""
echo ""

if [ -z "$API_KEY" ]; then
  echo "❌ No API key provided"
  exit 1
fi

echo "📡 Sending request to worker..."
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "https://testflight-welcome-worker.mikebmott.workers.dev" \
  -H "Authorization: Bearer $API_KEY")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
  echo "✅ Worker triggered successfully!"
  echo ""
  echo "$BODY"
  echo ""
  echo "📬 Check your inbox for the welcome email!"
  echo "📊 Check Cloudflare logs for details:"
  echo "   Run: npm run tail"
else
  echo "❌ Request failed with status $HTTP_CODE"
  echo "$BODY"
  exit 1
fi
