#!/usr/bin/env python3
"""Test Chandra OCR imports and basic usage."""

try:
    from chandra.input import load_file
    from chandra.output import to_markdown
    print("✅ Can import input/output modules")
except Exception as e:
    print(f"❌ Import failed: {e}")

try:
    import chandra
    print(f"✅ Chandra package: {chandra.__file__}")
except Exception as e:
    print(f"❌ Failed: {e}")

# Try to find the OCR function
try:
    from chandra.scripts.cli import main
    print("✅ Can import CLI main")
except Exception as e:
    print(f"❌ CLI import failed: {e}")
