#!/usr/bin/env python3
"""
Chandra OCR Direct Wrapper - Uses transformers directly
Provides /api/tags and /api/generate endpoints for QuillStack
"""

import base64
import json
import time
from io import BytesIO
from flask import Flask, request, jsonify
from PIL import Image

# We'll lazy-load these to avoid startup delays
processor = None
model = None

app = Flask(__name__)

# Configuration
MODEL_NAME = "chandra-ocr-2"
HF_MODEL_ID = "datalab-to/chandra-ocr-2"

def load_model():
    """Lazy load the model and processor."""
    global processor, model

    if model is None:
        print("Loading Chandra OCR model...")
        start = time.time()

        try:
            from transformers import AutoProcessor, AutoModelForCausalLM
            import torch

            # Load processor and model
            # Use AutoModel to automatically detect the correct architecture
            processor = AutoProcessor.from_pretrained(HF_MODEL_ID, trust_remote_code=True)
            model = AutoModelForCausalLM.from_pretrained(
                HF_MODEL_ID,
                torch_dtype=torch.float16,
                device_map="auto",
                trust_remote_code=True
            )

            elapsed = time.time() - start
            print(f"Model loaded in {elapsed:.1f}s")

        except Exception as e:
            print(f"Error loading model: {e}")
            raise

def process_image(image_data, prompt=""):
    """Process image using Chandra OCR."""
    load_model()

    # Decode image
    image = Image.open(BytesIO(image_data))

    # Prepare inputs
    # Chandra expects a specific prompt format for OCR
    if not prompt or "transcribe" not in prompt.lower():
        ocr_prompt = "Convert this image to markdown format. Transcribe all visible text exactly as written."
    else:
        ocr_prompt = prompt

    inputs = processor(
        text=ocr_prompt,
        images=image,
        return_tensors="pt"
    ).to(model.device)

    # Generate
    outputs = model.generate(
        **inputs,
        max_new_tokens=2048,
        do_sample=False
    )

    # Decode
    generated_text = processor.batch_decode(outputs, skip_special_tokens=True)[0]

    return generated_text

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint."""
    return jsonify({
        "status": "ok",
        "model": MODEL_NAME,
        "model_loaded": model is not None
    })

@app.route('/api/tags', methods=['GET'])
def tags():
    """Return available models in Ollama format."""
    # Trigger model loading in background if not loaded
    if model is None:
        import threading
        threading.Thread(target=load_model, daemon=True).start()

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
            },
            "modified_at": "2026-03-26T00:00:00Z"
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

        # Process with Chandra
        print(f"Processing OCR request...")
        start = time.time()

        markdown_text = process_image(image_data, prompt)

        elapsed = time.time() - start
        print(f"OCR completed in {elapsed:.1f}s")

        # Parse the markdown response into structured format
        response_json = {
            "text": markdown_text,
            "title": extract_title(markdown_text),
            "tags": extract_tags(markdown_text, prompt)
        }

        # Return in Ollama format
        return jsonify({
            "response": json.dumps(response_json),
            "model": MODEL_NAME,
            "done": True
        })

    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

def extract_title(text):
    """Extract first heading as title."""
    lines = text.split('\n')
    for line in lines:
        line = line.strip()
        if line.startswith('# '):
            return line[2:].strip()
    # Fallback: first non-empty line
    for line in lines:
        if line.strip():
            return line.strip()[:100]
    return None

def extract_tags(text, prompt):
    """Extract basic tags from content."""
    tags = []
    text_lower = text.lower()

    # Check if specific extractions were requested
    prompt_lower = prompt.lower() if prompt else ""

    # Simple keyword matching
    if 'receipt' in prompt_lower or any(word in text_lower for word in ['receipt', 'total', 'paid', '$']):
        tags.append('receipt')
    if 'event' in prompt_lower or any(word in text_lower for word in ['meeting', 'conference', 'event']):
        tags.append('event')
    if 'todo' in prompt_lower or any(word in text_lower for word in ['todo', 'task', '[ ]', '[x]']):
        tags.append('todo')
    if 'contact' in prompt_lower or any(word in text_lower for word in ['email', 'phone', '@']):
        tags.append('contact')

    return tags[:4]  # Limit to 4 tags

if __name__ == '__main__':
    print(f"Starting Chandra OCR wrapper on port 11434...")
    print(f"Model: {HF_MODEL_ID}")
    print(f"Note: Model will load on first request")

    app.run(host='0.0.0.0', port=11434, debug=False)
