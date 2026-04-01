#!/bin/bash
# sync-settings.sh — settings.base.json + settings.local.json → settings.json
# Usage: bash ~/.claude/scripts/sync-settings.sh

DIR="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$DIR/settings.base.json"
LOCAL="$DIR/settings.local.json"
OUT="$DIR/settings.json"

if [ ! -f "$BASE" ]; then
  echo "ERROR: $BASE not found" >&2
  exit 1
fi

if [ ! -f "$LOCAL" ]; then
  echo "No settings.local.json found — using base only"
  cp "$BASE" "$OUT"
  exit 0
fi

# Deep merge: local overrides base (local wins on conflicts)
python3 -c "
import json, sys

def deep_merge(base, override):
    result = base.copy()
    for k, v in override.items():
        if k.startswith('_'):
            continue
        if k in result and isinstance(result[k], dict) and isinstance(v, dict):
            result[k] = deep_merge(result[k], v)
        else:
            result[k] = v
    return result

with open('$BASE') as f:
    base = json.load(f)
with open('$LOCAL') as f:
    local = json.load(f)

merged = deep_merge(base, local)
with open('$OUT', 'w') as f:
    json.dump(merged, f, indent=2, ensure_ascii=False)
    f.write('\n')
" && echo "Merged → $OUT"
