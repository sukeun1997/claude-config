#!/usr/bin/env python3
"""
failure-log-instinct-boost.py

Scan memory/topics/failure-log.md for user-confirmed classifications and boost
matching instinct confidence. Confirmed = layer without "(추정)" suffix.

Called by: observer-runner.sh (after observation scan, before evolve check)

Design:
- Seen file (.failure-log-boost-seen) records "DATE|SYMPTOM" keys already processed
  — cursor approach misses in-place edits (추정 → 확정), so we track per-row keys
- Symptom pattern "N회 반복 편집" maps to sequence-repeated-edit instinct
- Each confirmed row bumps confidence by +0.05 (cap 0.95), observed_count +1
- Unconfirmed "(추정)" rows are ignored until user validates
"""
import os
import re
import sys
from pathlib import Path

HOME = Path.home()
FAILURE_LOG = HOME / ".claude/memory/topics/failure-log.md"
SEEN_FILE = HOME / ".claude/homunculus/.failure-log-boost-seen"
INSTINCTS_DIR = HOME / ".claude/homunculus/instincts/personal"

# Symptom pattern → instinct name mapping
SYMPTOM_TO_INSTINCT = {
    r"\d+회 반복 편집": "sequence-repeated-edit",
}

# Boost parameters
BOOST_PER_ROW = 0.05
CONF_CAP = 0.95

# Row format: | DATE | SYMPTOM | LAYER | HINT |
# Confirmed if LAYER is one of Prompt/Context/Harness WITHOUT "(추정)"
CONFIRMED_LAYER_RE = re.compile(
    r"^\|\s*(\d{4}-\d{2}-\d{2})\s*\|\s*(.+?)\s*\|\s*(Prompt|Context|Harness)\s*\|"
)
ROW_RE = re.compile(r"^\|\s*\d{4}-\d{2}-\d{2}\s*\|")


def match_instinct(symptom: str):
    for pattern, instinct_name in SYMPTOM_TO_INSTINCT.items():
        if re.search(pattern, symptom):
            return instinct_name
    return None


def bump_instinct(instinct_name: str, count: int):
    """Bump confidence and observed_count on an instinct file."""
    path = INSTINCTS_DIR / f"{instinct_name}.md"
    if not path.exists():
        return False, f"instinct not found: {instinct_name}"
    content = path.read_text()
    # Parse current confidence
    conf_m = re.search(r"^confidence:\s*([0-9.]+)\s*$", content, re.MULTILINE)
    if not conf_m:
        return False, "no confidence field"
    current = float(conf_m.group(1))
    new = min(CONF_CAP, round(current + BOOST_PER_ROW * count, 2))
    # Parse current observed_count
    obs_m = re.search(r"^observed_count:\s*(\d+)\s*$", content, re.MULTILINE)
    current_obs = int(obs_m.group(1)) if obs_m else 0
    new_obs = current_obs + count
    # Replace
    content = re.sub(
        r"^confidence:\s*[0-9.]+\s*$",
        f"confidence: {new}",
        content,
        count=1,
        flags=re.MULTILINE,
    )
    if obs_m:
        content = re.sub(
            r"^observed_count:\s*\d+\s*$",
            f"observed_count: {new_obs}",
            content,
            count=1,
            flags=re.MULTILINE,
        )
    path.write_text(content)
    return True, f"{current} → {new} (+{count} rows, obs {current_obs}→{new_obs})"


def main():
    if not FAILURE_LOG.exists():
        return 0

    # Load seen keys
    seen = set()
    if SEEN_FILE.exists():
        seen = {line.strip() for line in SEEN_FILE.read_text().splitlines() if line.strip()}

    lines = FAILURE_LOG.read_text().splitlines()

    # Tally boosts per instinct, collect new keys
    boosts = {}  # instinct_name -> count
    new_keys = []
    for raw in lines:
        m = CONFIRMED_LAYER_RE.match(raw)
        if not m:
            continue
        # Skip unconfirmed (추정) rows
        if "(추정)" in raw.split("|")[3]:
            continue
        date, symptom = m.group(1), m.group(2)
        key = f"{date}|{symptom}"
        if key in seen:
            continue
        instinct = match_instinct(symptom)
        if instinct:
            boosts[instinct] = boosts.get(instinct, 0) + 1
            new_keys.append(key)

    # Apply boosts
    reports = []
    for instinct, count in boosts.items():
        ok, msg = bump_instinct(instinct, count)
        status = "OK" if ok else "SKIP"
        reports.append(f"[{status}] {instinct} × {count}: {msg}")

    # Persist seen keys (only on successful processing)
    if new_keys:
        SEEN_FILE.parent.mkdir(parents=True, exist_ok=True)
        with SEEN_FILE.open("a") as f:
            for key in new_keys:
                f.write(key + "\n")

    if reports:
        print("\n".join(reports))

    return 0


if __name__ == "__main__":
    sys.exit(main())
