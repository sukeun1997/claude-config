#!/usr/bin/env python3
"""
Sync Claude skills into Codex skill tree with a basic compatibility filter.

Default source:
  ~/.claude/skills

Default target:
  ~/.codex/skills/omc-shared
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


HOME = Path.home()
DEFAULT_SOURCE = HOME / ".claude" / "skills"
DEFAULT_TARGET = HOME / ".codex" / "skills" / "omc-shared"

BLOCKER_PATTERNS: list[tuple[str, str]] = [
    (r"superpowers:", "superpowers 의존"),
    (r"mcp__claude", "Claude 전용 MCP"),
    (r"mcp__plugin_", "Claude plugin MCP"),
    (r"EnterPlanMode", "Claude Plan mode 전제"),
    (r"CLAUDE_CODE_", "Claude 전용 환경변수"),
    (r"claude-plugins-official", "Claude plugin 전제"),
]


@dataclass
class SkillInfo:
    name: str
    directory: Path
    skill_file: Path
    reasons: list[str]

    @property
    def portable(self) -> bool:
        return not self.reasons


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Sync Claude skills into Codex skill tree."
    )
    parser.add_argument(
        "--source",
        type=Path,
        default=DEFAULT_SOURCE,
        help=f"Claude skills root (default: {DEFAULT_SOURCE})",
    )
    parser.add_argument(
        "--target",
        type=Path,
        default=DEFAULT_TARGET,
        help=f"Codex target root (default: {DEFAULT_TARGET})",
    )
    parser.add_argument(
        "--mode",
        choices=("copy", "symlink"),
        default="copy",
        help="Sync mode (default: copy)",
    )
    parser.add_argument(
        "--skill",
        action="append",
        default=[],
        help="Specific skill name to sync. Repeatable.",
    )
    parser.add_argument(
        "--include-incompatible",
        action="store_true",
        help="Include skills that hit compatibility blockers.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would change without writing.",
    )
    parser.add_argument(
        "--clean-target",
        action="store_true",
        help="Remove target skill directories that are not selected this run.",
    )
    return parser.parse_args()


def iter_skill_files(source: Path) -> Iterable[Path]:
    for path in sorted(source.rglob("*")):
        if path.is_file() and path.name in {"SKILL.md", "skill.md"}:
            yield path


def load_skill_info(skill_file: Path, source_root: Path) -> SkillInfo:
    directory = skill_file.parent
    name = str(directory.relative_to(source_root))
    reasons: list[str] = []
    for path in sorted(directory.rglob("*")):
        if not path.is_file():
            continue
        try:
            if path.stat().st_size > 200_000:
                continue
            content = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for pattern, reason in BLOCKER_PATTERNS:
            if re.search(pattern, content, flags=re.IGNORECASE):
                reasons.append(reason)
    return SkillInfo(
        name=name,
        directory=directory,
        skill_file=skill_file,
        reasons=sorted(set(reasons)),
    )


def ensure_clean_target_dir(path: Path, dry_run: bool) -> None:
    if path.is_symlink() or path.is_file():
        if dry_run:
            print(f"REMOVE {path}")
        else:
            path.unlink()
        return
    if path.is_dir():
        if dry_run:
            print(f"REMOVE {path}")
        else:
            shutil.rmtree(path)


def copy_skill(src_dir: Path, dst_dir: Path, dry_run: bool) -> None:
    if dry_run:
        print(f"COPY   {src_dir} -> {dst_dir}")
        return
    if dst_dir.exists() or dst_dir.is_symlink():
        ensure_clean_target_dir(dst_dir, dry_run=False)
    shutil.copytree(src_dir, dst_dir)
    for child in dst_dir.iterdir():
        if child.is_file() and child.name.lower() == "skill.md" and child.name != "SKILL.md":
            upper = dst_dir / "SKILL.md"
            temp = dst_dir / "__skill_sync_tmp__.md"
            child.rename(temp)
            temp.rename(upper)
            break


def symlink_skill(src_dir: Path, dst_dir: Path, dry_run: bool) -> None:
    if dry_run:
        print(f"SYMLINK {dst_dir} -> {src_dir}")
        return
    if dst_dir.exists() or dst_dir.is_symlink():
        ensure_clean_target_dir(dst_dir, dry_run=False)
    dst_dir.parent.mkdir(parents=True, exist_ok=True)
    os.symlink(src_dir, dst_dir, target_is_directory=True)


def main() -> int:
    args = parse_args()
    source = args.source.expanduser()
    target = args.target.expanduser()

    if not source.exists():
        print(f"ERROR: source not found: {source}", file=sys.stderr)
        return 1

    selected_names = set(args.skill)
    infos = [load_skill_info(path, source) for path in iter_skill_files(source)]

    if selected_names:
        infos = [info for info in infos if info.name in selected_names]

    portable: list[SkillInfo] = []
    blocked: list[SkillInfo] = []
    for info in infos:
        if info.portable or args.include_incompatible:
            portable.append(info)
        else:
            blocked.append(info)

    print(f"SOURCE: {source}")
    print(f"TARGET: {target}")
    print(f"MODE:   {args.mode}")
    print(f"TOTAL:  {len(infos)}")
    print(f"SYNC:   {len(portable)}")
    print(f"SKIP:   {len(blocked)}")

    if blocked:
        print("\n[SKIPPED: compatibility blockers]")
        for info in blocked:
            print(f"- {info.name}: {', '.join(info.reasons)}")

    if not args.dry_run:
        target.mkdir(parents=True, exist_ok=True)

    chosen_names = set()
    for info in portable:
        chosen_names.add(info.name)
        dst_dir = target / info.name
        dst_dir.parent.mkdir(parents=True, exist_ok=True) if not args.dry_run else None
        if args.mode == "copy":
            copy_skill(info.directory, dst_dir, dry_run=args.dry_run)
        else:
            symlink_skill(info.directory, dst_dir, dry_run=args.dry_run)

    if args.clean_target and target.exists():
        existing = sorted(
            path
            for path in target.iterdir()
            if path.is_dir() or path.is_symlink()
        )
        for path in existing:
            rel = str(path.relative_to(target))
            if rel not in chosen_names:
                ensure_clean_target_dir(path, dry_run=args.dry_run)

    print("\n[DONE]")
    if args.dry_run:
        print("No files were changed.")
    else:
        print(f"Synced into {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
