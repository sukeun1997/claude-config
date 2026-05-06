#!/usr/bin/env bash
# instinct-evolve.sh — Cluster high-confidence instincts into evolved skills
# Called by: observer-runner.sh (not a standalone hook)
# Logic: Same domain + confidence >= COLLECTION_THRESHOLD (0.55, lowered 2026-04-18
#        based on cluster-depth analysis) + 3 or more → merge into evolved/skills/.
#        A separate PROMOTION_THRESHOLD (0.7) gates the symlink into skills/ so
#        only mature clusters surface to the live skill loader (one-way promotion —
#        confidence downgrades do not auto-unpublish).

set -euo pipefail

HOMUNCULUS_DIR="$HOME/.claude/homunculus"
INSTINCTS_DIR="$HOMUNCULUS_DIR/instincts/personal"
EVOLVED_DIR="$HOMUNCULUS_DIR/evolved/skills"

# Exit early if no instincts
[ -d "$INSTINCTS_DIR" ] || exit 0
mkdir -p "$EVOLVED_DIR"

# Parse instincts: extract domain, confidence, evolved status
python3 << 'PYEOF'
import os, re, sys
from collections import defaultdict
from pathlib import Path

COLLECTION_THRESHOLD = 0.55  # see header comment — kept in sync with L10

instincts_dir = os.path.expanduser("~/.claude/homunculus/instincts/personal")
evolved_dir = os.path.expanduser("~/.claude/homunculus/evolved/skills")

# Parse all instinct files
instincts_by_domain = defaultdict(list)

for f in Path(instincts_dir).glob("*.md"):
    content = f.read_text()

    # Skip already evolved
    if "evolved: true" in content:
        continue

    # Extract frontmatter fields
    confidence = 0.0
    domain = "general"
    name = f.stem

    conf_match = re.search(r'confidence:\s*([0-9.]+)', content)
    if conf_match:
        confidence = float(conf_match.group(1))

    domain_match = re.search(r'domain:\s*"?([^"\s]+)"?', content)
    if domain_match:
        domain = domain_match.group(1).strip('"')

    # Only consider high-confidence instincts (threshold defined at top of this block)
    if confidence >= COLLECTION_THRESHOLD:
        instincts_by_domain[domain].append({
            "name": name,
            "confidence": confidence,
            "path": str(f),
            "content": content
        })

# Check for clusters (3+ instincts in same domain)
evolved_count = 0
for domain, instincts in instincts_by_domain.items():
    if len(instincts) < 3:
        continue

    # Sort by confidence descending
    instincts.sort(key=lambda x: x["confidence"], reverse=True)

    # Check if evolved skill already exists
    evolved_path = os.path.join(evolved_dir, f"{domain}.md")
    if os.path.exists(evolved_path):
        continue

    # Create evolved skill
    skill_content = f"""---
name: {domain}-patterns
description: Auto-evolved skill from {len(instincts)} high-confidence {domain} instincts
domain: {domain}
source: instinct-evolve.sh
confidence: {sum(i['confidence'] for i in instincts) / len(instincts):.2f}
---

# {domain.title()} Patterns (Auto-Evolved)

Clustered from {len(instincts)} instincts with confidence >= {COLLECTION_THRESHOLD} (min in cluster: {min(i['confidence'] for i in instincts):.2f}).

## Rules

"""
    for inst in instincts:
        # Extract action/trigger from instinct content
        action_match = re.search(r'action:\s*"?(.+?)"?\s*$', inst["content"], re.MULTILINE)
        trigger_match = re.search(r'trigger:\s*"?(.+?)"?\s*$', inst["content"], re.MULTILINE)

        action = action_match.group(1) if action_match else "(see source instinct)"
        trigger = trigger_match.group(1) if trigger_match else "(always)"

        skill_content += f"### {inst['name']} (confidence: {inst['confidence']})\n"
        skill_content += f"- **When**: {trigger}\n"
        skill_content += f"- **Do**: {action}\n\n"

    # Write evolved skill
    with open(evolved_path, "w") as ef:
        ef.write(skill_content)

    # Mark source instincts as evolved
    for inst in instincts:
        inst_content = Path(inst["path"]).read_text()
        if "evolved:" not in inst_content:
            # Add evolved: true to frontmatter
            inst_content = inst_content.replace("---\n\n", "evolved: true\n---\n\n", 1)
            Path(inst["path"]).write_text(inst_content)

    evolved_count += 1
    print(f"Evolved: {domain} ({len(instincts)} instincts → {evolved_path})")

if evolved_count == 0:
    # Silent exit — no clusters ready yet
    pass
PYEOF

# ── Promotion: symlink high-confidence evolved skills into skills/ ──
# Threshold: confidence >= 0.7 (from frontmatter). Below that stays in staging.
# Skill loader scans skills/*/SKILL.md — create skills/evolved-{domain}/ dir + symlink.
SKILLS_DIR="$HOME/.claude/skills"
PROMOTION_THRESHOLD="0.7"
for evolved_file in "$EVOLVED_DIR"/*.md; do
  [ -f "$evolved_file" ] || continue
  domain=$(basename "$evolved_file" .md)
  conf=$(awk '/^confidence:/ {print $2; exit}' "$evolved_file" 2>/dev/null || echo "0")
  # Numeric compare (awk for float)
  promote=$(awk -v c="$conf" -v t="$PROMOTION_THRESHOLD" 'BEGIN { print (c+0 >= t+0) ? "yes" : "no" }')
  [ "$promote" = "yes" ] || continue

  skill_dir="$SKILLS_DIR/evolved-${domain}"
  link_path="$skill_dir/SKILL.md"
  mkdir -p "$skill_dir"
  # Idempotent: recreate symlink if target changed or missing
  if [ ! -L "$link_path" ] || [ "$(readlink "$link_path")" != "../../homunculus/evolved/skills/${domain}.md" ]; then
    ln -sf "../../homunculus/evolved/skills/${domain}.md" "$link_path"
    echo "Promoted: evolved-${domain} (confidence ${conf}) → $link_path"
  fi
done

exit 0
