#!/usr/bin/env python3
"""
Fail when a skill that both harnesses share has drifted.

sync-codex-skills.py only writes into ~/.codex/skills/omc-shared, so shared
skills that live under omc-learned/ or the codex root drift silently. This
checks the explicit pairs instead of a directory.
"""

from __future__ import annotations

import difflib
import os
import sys
from pathlib import Path

HOME = Path.home()
# Overridable so the check can run against a worktree before merge.
CLAUDE = Path(os.environ.get("CLAUDE_HOME", HOME / ".claude")) / "skills"
CODEX = Path(os.environ.get("CODEX_HOME", HOME / ".codex")) / "skills"

# Same policy, one text. Any difference is drift.
IDENTICAL: list[tuple[str, str]] = [
    ("kotlin-patterns", "omc-shared/kotlin-patterns"),
    ("backend-code-quality-review", "omc-learned/backend-code-quality-review"),
    ("domain-modeling-gate", "omc-learned/domain-modeling-gate"),
    ("incident-analysis", "omc-learned/incident-analysis"),
    ("sentry-flow-rca", "sentry-flow-rca"),
]

# Harness-specific mechanics (subagent syntax, save paths). Presence is checked,
# content is not.
ADAPTED: list[tuple[str, str, str]] = [
    ("code-trace", "omc-shared/code-trace", "subagent 호출 문법이 다름"),
]


START, END = "<!-- harness-specific:start -->", "<!-- harness-specific:end -->"


def read(path: Path) -> list[str] | None:
    """Return the policy text: everything outside harness-specific blocks.

    Each harness names its own skills (`$ecr` vs `/ecr`, `analyze` and
    `multi-option-feedback` exist only in Codex, `lecture-review-lens` only in
    Claude). Wrap those lines in the markers so the surrounding policy stays
    under drift protection instead of exempting the whole file.
    """
    try:
        lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    except OSError:
        return None

    kept, skipping = [], False
    for line in lines:
        stripped = line.strip()
        if stripped == START:
            skipping = True
        elif stripped == END:
            skipping = False
        elif not skipping:
            kept.append(line)
    return kept


def main() -> int:
    failures = 0

    for claude_rel, codex_rel in IDENTICAL:
        a_path, b_path = CLAUDE / claude_rel / "SKILL.md", CODEX / codex_rel / "SKILL.md"
        a, b = read(a_path), read(b_path)
        if a is None or b is None:
            print(f"MISSING  {claude_rel}: {'claude' if a is None else 'codex'} 쪽 없음")
            failures += 1
            continue
        if a == b:
            print(f"OK       {claude_rel}")
            continue
        delta = sum(1 for line in difflib.unified_diff(a, b, n=0) if line[:1] in "+-")
        print(f"DRIFT    {claude_rel}: {delta}줄 차이")
        print(f"         diff {a_path} {b_path}")
        failures += 1

    for claude_rel, codex_rel, reason in ADAPTED:
        missing = [
            side
            for side, path in (("claude", CLAUDE / claude_rel), ("codex", CODEX / codex_rel))
            if not (path / "SKILL.md").is_file()
        ]
        if missing:
            print(f"MISSING  {claude_rel}: {', '.join(missing)} 쪽 없음")
            failures += 1
        else:
            print(f"ADAPTED  {claude_rel} ({reason})")

    if failures:
        print(f"\n{failures}건 표류. 정본을 정한 뒤 반대쪽에 복사하고 다시 실행하세요.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
