#!/usr/bin/env python3
"""
Tag experiment — send images to Ollama and see what tags it suggests.

Usage:
    python3 scripts/tag-experiment.py image1.jpg [image2.png ...]
    python3 scripts/tag-experiment.py ~/Photos/*.jpg
"""

import sys
import json
import base64
import urllib.request
from pathlib import Path

OLLAMA_HOST = "http://100.74.153.99:11434"  # Tailscale Mac Mini
MODEL = "qwen3-vl:8b"


def encode_image(path: Path) -> str:
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


def build_prompt() -> str:
    return (
        "/no_think "
        "You are a document tagger. Look at this image and suggest up to 4 tags "
        "that describe the SUBJECT MATTER and TOPICS, not the physical format. "
        "Do not use tags like 'handwritten', 'notebook', 'notes', or 'page'. "
        "Tags should be lowercase, 1-2 words each. "
        "Return JSON: {\"tags\": [\"tag1\", \"tag2\", ...]}"
    )


def tag_image(image_path: Path) -> dict:
    payload = json.dumps({
        "model": MODEL,
        "prompt": build_prompt(),
        "images": [encode_image(image_path)],
        "format": "json",
        "stream": False,
    }).encode()

    req = urllib.request.Request(
        f"{OLLAMA_HOST}/api/generate",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    req.timeout = 120

    with urllib.request.urlopen(req) as resp:
        result = json.loads(resp.read())

    response_text = result.get("response", "")
    thinking_text = result.get("thinking", "")

    # Qwen3 with thinking mode may put JSON in either field
    for text in [response_text, thinking_text]:
        if text:
            try:
                return json.loads(text)
            except json.JSONDecodeError:
                continue

    if response_text:
        return {"raw": response_text, "error": "failed to parse JSON"}
    if thinking_text:
        return {"raw": thinking_text[:500], "error": "content in thinking field only"}
    return {"error": "empty response"}


def main():
    if len(sys.argv) < 2:
        print(__doc__.strip())
        sys.exit(1)

    paths = [Path(p) for p in sys.argv[1:]]
    missing = [p for p in paths if not p.exists()]
    if missing:
        print(f"Not found: {', '.join(str(p) for p in missing)}")
        sys.exit(1)

    for path in paths:
        print(f"\n{'─' * 50}")
        print(f"  {path.name}")
        print(f"{'─' * 50}")
        result = tag_image(path)

        if "tags" in result:
            for tag in result["tags"]:
                print(f"  #{tag}")
        else:
            print(f"  {result}")


if __name__ == "__main__":
    main()
