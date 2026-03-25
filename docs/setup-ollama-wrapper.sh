#!/bin/bash
# Setup Ollama on-demand wrapper on remote server

set -e

echo "Setting up Ollama on-demand wrapper..."

# Install Flask if not present
echo "Installing Python dependencies..."
pip3 install flask requests

# Copy wrapper script
SCRIPT_PATH="$HOME/ollama-wrapper.py"
cp ollama-wrapper.py "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"

# Update LaunchAgent plist with actual username
PLIST_PATH="$HOME/Library/LaunchAgents/com.ollama.wrapper.plist"
sed "s|YOUR_USERNAME|$USER|g" com.ollama.wrapper.plist > "$PLIST_PATH"

# Unload any existing Ollama service
echo "Unloading existing Ollama service if present..."
launchctl unload ~/Library/LaunchAgents/com.ollama.serve.plist 2>/dev/null || true

# Load new wrapper service
echo "Loading wrapper service..."
launchctl load "$PLIST_PATH"

echo ""
echo "✅ Setup complete!"
echo ""
echo "The wrapper is now running on port 11434"
echo "Ollama will start automatically when OCR requests arrive"
echo "and stop after 5 minutes of inactivity"
echo ""
echo "Logs: /tmp/ollama-wrapper.log"
echo "Errors: /tmp/ollama-wrapper.err"
echo ""
echo "To check status:"
echo "  curl http://localhost:11434/health"
echo ""
echo "To unload:"
echo "  launchctl unload ~/Library/LaunchAgents/com.ollama.wrapper.plist"
