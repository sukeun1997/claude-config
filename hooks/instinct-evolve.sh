#!/usr/bin/env bash
# instinct-evolve.sh — Cluster high-confidence instincts into evolved skills
# Called by: observer-runner.sh (not a standalone hook)
# Logic: Same domain + confidence >= 0.7 + 3 or more → merge into evolved/skills/

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

    # Only consider high-confidence instincts (lowered 0.7→0.6 for faster evolution,
    # based on critic analysis 2026-04-18: single domain clustering was unreachable at 0.7)
    if confidence >= 0.6:
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

Clustered from {len(instincts)} instincts with confidence >= 0.7.

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

exit 0
