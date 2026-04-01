#!/usr/bin/env python3
"""
Chandra OCR Wrapper - Ollama-compatible API
Provides /api/tags and /api/generate endpoints for QuillStack
"""

import subprocess
import base64
import json
import time
from flask import Flask, request, jsonify
from pathlib import Path
import tempfile

app = Flask(__name__)

# Configuration
MODEL_NAME = "chandra-ocr-2"
CHANDRA_ENV_PATH = Path(__file__).parent / "docs" / "chandra-env"
CHANDRA_BIN = CHANDRA_ENV_PATH / "bin" / "chandra"

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint."""
    return jsonify({"status": "ok", "model": MODEL_NAME})

@app.route('/api/tags', methods=['GET'])
def tags():
    """Return available models in Ollama format."""
    return jsonify({
        "models": [{
            "name": MODEL_NAME,
            "model": MODEL_NAME,
            "size": 9900000000,  # ~9.9GB
            "digest": "chandra-ocr-2-hf",
            "details": {
                "format": "huggingface",
                "family": "chandra",
                "parameter_size": "4B"
            }
        }]
    })

@app.route('/api/generate', methods=['POST'])
def generate():
    """Process OCR request using Chandra."""
    try:
        data = request.json

        # Extract parameters
        images = data.get('images', [])
        prompt = data.get('prompt', '')

        if not images:
            return jsonify({"error": "No image provided"}), 400

        # Decode base64 image
        image_data = base64.b64decode(images[0])

        # Save to temp file
        with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as tmp:
            tmp.write(image_data)
            tmp_path = tmp.name

        try:
            # Run chandra CLI
            # Note: We'll use a simple subprocess call as a fallback
            result = subprocess.run(
                [str(CHANDRA_BIN), tmp_path, '--format', 'markdown'],
                capture_output=True,
                text=True,
                timeout=120
            )

            if result.returncode != 0:
                return jsonify({"error": f"Chandra failed: {result.stderr}"}), 500

            # Extract text from output
            markdown_text = result.stdout.strip()

            # Parse the markdown response into structured format
            # For now, return simple text - we can enhance this later
            response_json = {
                "text": markdown_text,
                "title": extract_title(markdown_text),
                "tags": extract_tags(markdown_text)
            }

            # Return in Ollama format
            return jsonify({
                "response": json.dumps(response_json),
                "model": MODEL_NAME,
                "done": True
            })

        finally:
            # Clean up temp file
            Path(tmp_path).unlink(missing_ok=True)

    except Exception as e:
        return jsonify({"error": str(e)}), 500

def extract_title(text):
    """Extract first heading as title."""
    lines = text.split('\n')
    for line in lines:
        if line.startswith('# '):
            return line[2:].strip()
    # Fallback: first non-empty line
    for line in lines:
        if line.strip():
            return line.strip()[:100]
    return None

def extract_tags(text):
    """Extract basic tags from content."""
    tags = []
    text_lower = text.lower()

    # Simple keyword matching
    if any(word in text_lower for word in ['receipt', 'total', 'paid', '$']):
        tags.append('receipt')
    if any(word in text_lower for word in ['meeting', 'conference', 'event']):
        tags.append('event')
    if any(word in text_lower for word in ['todo', 'task', '[ ]', '[x]']):
        tags.append('todo')

    return tags[:4]  # Limit to 4 tags

if __name__ == '__main__':
    print(f"Starting Chandra OCR wrapper on port 11434...")
    print(f"Model: {MODEL_NAME}")
    print(f"Chandra binary: {CHANDRA_BIN}")

    # Check if chandra binary exists
    if not CHANDRA_BIN.exists():
        print(f"ERROR: Chandra binary not found at {CHANDRA_BIN}")
        exit(1)

    app.run(host='0.0.0.0', port=11434, debug=False)
