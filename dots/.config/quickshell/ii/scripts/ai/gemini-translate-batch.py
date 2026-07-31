#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Helper script to translate missing JSON keys in batches using Google Gemini API.
"""

import os
import sys
import json
import urllib.request
import urllib.error
import argparse
from pathlib import Path

def get_api_key() -> str:
    # First try environment variable
    api_key = os.environ.get("GEMINI_API_KEY", "")
    if api_key:
        return api_key.strip()
    
    # Try secret-tool lookup
    try:
        import subprocess
        result = subprocess.run(
            ["secret-tool", "lookup", "application", "illogical-impulse"],
            capture_output=True, text=True, check=True
        )
        data = json.loads(result.stdout.strip())
        return data.get("apiKeys", {}).get("gemini", "")
    except Exception as e:
        print(f"Error fetching API key via secret-tool: {e}", file=sys.stderr)
        return ""

def translate_batch(batch_dict: dict, target_locale: str, api_key: str, model: str) -> dict:
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
    headers = {
        "x-goog-api-key": api_key,
        "Content-Type": "application/json"
    }
    
    instruction = (
        "You are to translate the user interface of a **desktop shell**. "
        "Given a JSON object of key-value pairs, return a JSON with the exact same structure, "
        f"with keys unchanged and values translated to {target_locale}. "
        "Be as **concise** as possible to save screen space, and make sure terminology is relevant "
        '(e.g. "discharging" refers to the battery status).'
    )
    
    prompt = f"{instruction}\n```json\n{json.dumps(batch_dict, ensure_ascii=False, indent=2)}\n```\n"
    
    payload = {
        "contents": [{
            "parts": [{"text": prompt}]
        }],
        "generationConfig": {
            "temperature": 0.0,
            "responseMimeType": "application/json"
        }
    }
    
    req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST")
    
    try:
        with urllib.request.urlopen(req) as resp:
            res_data = json.loads(resp.read().decode("utf-8"))
            text = res_data["candidates"][0]["content"]["parts"][0]["text"]
            translated_dict = json.loads(text)
            if isinstance(translated_dict, dict):
                return translated_dict
            else:
                print("Warning: Response is not a JSON object", file=sys.stderr)
                return {}
    except Exception as e:
        print(f"Batch translation API error: {e}", file=sys.stderr)
        return {}

def main():
    parser = argparse.ArgumentParser(description="Translate missing JSON keys in batches using Gemini API")
    parser.add_argument("source_file", help="Path to source en_US.json file")
    parser.add_argument("target_file", help="Path to target locale JSON file (e.g. pt_BR.json)")
    parser.add_argument("target_locale", help="Target locale code (e.g. pt_BR)")
    parser.add_argument("--model", default="gemini-2.5-flash", help="Gemini model name")
    parser.add_argument("--batch-size", type=int, default=300, help="Keys per batch (default: 300)")
    
    args = parser.parse_args()
    
    api_key = get_api_key()
    if not api_key:
        print("Error: Gemini API key not found.", file=sys.stderr)
        sys.exit(1)
        
    source_path = Path(args.source_file)
    target_path = Path(args.target_file)
    
    if not source_path.exists():
        print(f"Error: Source file {source_path} does not exist.", file=sys.stderr)
        sys.exit(1)
        
    with open(source_path, "r", encoding="utf-8") as f:
        source_data = json.load(f)
        
    target_data = {}
    if target_path.exists():
        try:
            with open(target_path, "r", encoding="utf-8") as f:
                target_data = json.load(f)
        except Exception as e:
            print(f"Warning: Could not parse existing target file: {e}", file=sys.stderr)
            target_data = {}

    # Identify missing keys or keys where value is untranslated (same as key or empty)
    missing_items = {}
    for key, val in source_data.items():
        existing_val = target_data.get(key)
        # Key is missing OR existing value is empty
        if existing_val is None or existing_val == "":
            missing_items[key] = val

    print(f"Total source keys: {len(source_data)}")
    print(f"Existing valid translations: {len(target_data)}")
    print(f"Keys needing translation: {len(missing_items)}")

    if not missing_items:
        print("All keys are already translated!")
        sys.exit(0)

    items = list(missing_items.items())
    total_missing = len(items)
    batch_size = args.batch_size
    
    for i in range(0, total_missing, batch_size):
        batch_slice = items[i:i + batch_size]
        batch_dict = dict(batch_slice)
        batch_num = (i // batch_size) + 1
        total_batches = (total_missing + batch_size - 1) // batch_size
        
        print(f"Translating batch {batch_num}/{total_batches} ({len(batch_dict)} keys)...")
        translated_batch = translate_batch(batch_dict, args.target_locale, api_key, args.model)
        
        if translated_batch:
            # Merge translated keys into target_data
            for k, v in translated_batch.items():
                if k in source_data:
                    target_data[k] = v
            
            # Save progress after each batch
            target_path.parent.mkdir(parents=True, exist_ok=True)
            with open(target_path, "w", encoding="utf-8") as f:
                json.dump(target_data, f, ensure_ascii=False, indent=2)
            print(f"Batch {batch_num}/{total_batches} saved. Total translated: {len(target_data)}")
        else:
            print(f"Failed to translate batch {batch_num}/{total_batches}", file=sys.stderr)

    print(f"Translation complete! Final total keys in {target_path.name}: {len(target_data)}")

if __name__ == "__main__":
    main()
