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
# Frozen keys: hooks, permissions — always use base values (local cannot override)
python3 -c "
import json, sys

FROZEN_KEYS = {'hooks', 'permissions'}

def deep_merge(base, override, depth=0):
    result = base.copy()
    for k, v in override.items():
        if k.startswith('_'):
            continue
        if depth == 0 and k in FROZEN_KEYS:
            print(f'  [frozen] {k} — base value preserved', file=sys.stderr)
            continue
        if k in result and isinstance(result[k], dict) and isinstance(v, dict):
            result[k] = deep_merge(result[k], v, depth + 1)
        else:
            result[k] = v
    return result

with open('$BASE') as f:
    base = json.load(f)
with open('$LOCAL') as f:
    local = json.load(f)

merged = deep_merge(base, local)

# Validate: hooks must exist with at least 3 event types
hooks = merged.get('hooks', {})
if not isinstance(hooks, dict) or len(hooks) < 3:
    print(f'ERROR: hooks section invalid ({len(hooks) if isinstance(hooks, dict) else \"missing\"}) — aborting merge', file=sys.stderr)
    sys.exit(1)

with open('$OUT', 'w') as f:
    json.dump(merged, f, indent=2, ensure_ascii=False)
    f.write('\n')
" && echo "Merged → $OUT"
