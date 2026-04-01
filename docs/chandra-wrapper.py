#!/usr/bin/env python3
"""
Chandra OCR Wrapper - Ollama-compatible API
Uses Datalab's hosted API (api.datalab.to)
"""

import base64
import json
import time
from io import BytesIO
from flask import Flask, request, jsonify
from PIL import Image
import requests

app = Flask(__name__)

# Configuration
MODEL_NAME = "chandra-ocr-2"
DATALAB_API_KEY = "bFtn9s_o7WiNEk2jFvUGWTbuZsXv_skFE_LwZhaotj0"
DATALAB_BASE_URL = "https://www.datalab.to/api/v1"

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint."""
    return jsonify({
        "status": "ok",
        "model": MODEL_NAME,
        "model_loaded": True,
        "backend": "datalab_hosted"
    })

@app.route('/api/tags', methods=['GET'])
def tags():
    """Return available models in Ollama format."""
    return jsonify({
        "models": [{
            "name": MODEL_NAME,
            "model": MODEL_NAME,
            "size": 0,
            "digest": "chandra-ocr-2-hosted",
            "details": {
                "format": "api",
                "family": "chandra",
                "parameter_size": "4B",
                "backend": "datalab_hosted"
            },
            "modified_at": "2026-03-26T00:00:00Z"
        }]
    })

@app.route('/api/generate', methods=['POST'])
def generate():
    """Process OCR request using Datalab's hosted API."""
    try:
        print(f"Received generate request")
        data = request.json
        print(f"Request data keys: {list(data.keys()) if data else 'None'}")

        images = data.get('images', []) if data else []
        prompt = data.get('prompt', '') if data else ''

        print(f"Images count: {len(images)}, Prompt length: {len(prompt)}")

        if not images:
            print("ERROR: No images in request!")
            return jsonify({"error": "No image provided"}), 400

        # Decode image
        image_data = base64.b64decode(images[0])
        image = Image.open(BytesIO(image_data))

        # Convert RGBA to RGB if needed
        if image.mode in ('RGBA', 'LA', 'P'):
            rgb_image = Image.new('RGB', image.size, (255, 255, 255))
            rgb_image.paste(image, mask=image.split()[-1] if image.mode == 'RGBA' else None)
            image = rgb_image

        # Convert to bytes
        buffered = BytesIO()
        image.save(buffered, format="JPEG", quality=85)
        buffered.seek(0)

        print(f"Processing OCR request via Datalab API...")

        # Submit conversion request
        headers = {"X-API-Key": DATALAB_API_KEY}
        files = {"file": ("image.jpg", buffered, "image/jpeg")}
        form_data = {
            "output_format": "markdown",
            "mode": "fast"
        }

        response = requests.post(
            f"{DATALAB_BASE_URL}/convert",
            headers=headers,
            files=files,
            data=form_data,
            timeout=30
        )

        if response.status_code != 200:
            print(f"Datalab API error: {response.status_code} - {response.text}")
            return jsonify({"error": f"API error: {response.status_code}"}), 500

        result = response.json()
        request_id = result.get('request_id')

        if not request_id:
            return jsonify({"error": "No request_id returned"}), 500

        print(f"Request submitted, ID: {request_id}, polling for result...")

        # Poll for result (max 120 seconds)
        max_polls = 120
        poll_interval = 1

        for i in range(max_polls):
            time.sleep(poll_interval)

            try:
                poll_response = requests.get(
                    f"{DATALAB_BASE_URL}/convert/{request_id}",
                    headers=headers,
                    timeout=30
                )

                if poll_response.status_code != 200:
                    print(f"Poll {i+1}: status {poll_response.status_code}, retrying...")
                    continue

                poll_result = poll_response.json()
                status = poll_result.get('status')
                print(f"Poll {i+1}: status={status}")
            except requests.exceptions.RequestException as e:
                print(f"Poll {i+1}: network error ({e}), retrying...")
                continue

            if status == 'COMPLETED':
                markdown_text = poll_result.get('markdown', '')

                if not markdown_text:
                    return jsonify({"error": "Empty response from API"}), 500

                print(f"OCR completed successfully ({len(markdown_text)} chars)")

                # Parse response
                response_json = {
                    "text": markdown_text,
                    "title": extract_title(markdown_text),
                    "tags": extract_tags(markdown_text, prompt)
                }

                return jsonify({
                    "response": json.dumps(response_json),
                    "model": MODEL_NAME,
                    "done": True
                })

            elif status == 'FAILED':
                error = poll_result.get('error', 'Unknown error')
                print(f"Datalab API processing failed: {error}")
                return jsonify({"error": f"Processing failed: {error}"}), 500

        # Timeout
        print(f"Polling timeout after {max_polls} seconds")
        return jsonify({"error": "Processing timeout"}), 504

    except Exception as e:
        error_msg = f"Error: {e}"
        print(error_msg)
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

def extract_title(text):
    """Extract title from text."""
    lines = text.split('\n')
    for line in lines:
        line = line.strip()
        if line.startswith('# '):
            return line[2:].strip()
    for line in lines:
        if line.strip():
            return line.strip()[:100]
    return None

def extract_tags(text, prompt):
    """Extract tags from text."""
    tags = []
    text_lower = text.lower()
    prompt_lower = prompt.lower() if prompt else ""

    if 'receipt' in prompt_lower or any(w in text_lower for w in ['receipt', 'total', '$']):
        tags.append('receipt')
    if 'event' in prompt_lower or any(w in text_lower for w in ['meeting', 'event']):
        tags.append('event')
    if 'todo' in prompt_lower or any(w in text_lower for w in ['todo', 'task']):
        tags.append('todo')
    if 'contact' in prompt_lower or any(w in text_lower for w in ['email', 'phone', '@']):
        tags.append('contact')

    return tags[:4]

if __name__ == '__main__':
    print(f"Starting Chandra OCR wrapper on port 11434...")
    print(f"Model: {MODEL_NAME}")
    print(f"Backend: Datalab hosted API (www.datalab.to)")
    print(f"Compatible with Ollama API format")

    app.run(host='0.0.0.0', port=11434, debug=False)
