#!/usr/bin/env python3
"""Select relevant live lecture notes without maintaining a static manifest."""

from __future__ import annotations

import argparse
import json
import os
import re
from datetime import datetime
from pathlib import Path
from typing import Any


DEFAULT_ROOT = Path.home() / "vault" / "30 학습" / "강의"
FOCUS_SECTIONS = {
    "one-line takeaway": "One-Line Takeaway",
    "5줄 복습": "5줄 복습",
    "my interpretation": "My Interpretation",
    "practice": "Practice",
    "work relevance": "Work Relevance",
    "follow-up questions": "Follow-Up Questions",
}
STOP_WORDS = {
    "그리고",
    "그러나",
    "대한",
    "관련",
    "리뷰",
    "코드",
    "변경",
    "확인",
    "the",
    "and",
    "for",
    "with",
    "from",
    "this",
    "that",
    "review",
    "code",
}
TOKEN_PATTERN = re.compile(r"[0-9A-Za-z가-힣][0-9A-Za-z가-힣_.-]+")
HEADING_PATTERN = re.compile(r"^(#{1,6})\s+(.+?)\s*$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Rank Markdown lecture notes for a focused review query."
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(os.environ.get("LECTURE_NOTES_ROOT", DEFAULT_ROOT)),
        help="Lecture root. Defaults to LECTURE_NOTES_ROOT or ~/vault/30 학습/강의.",
    )
    parser.add_argument("--query", default="", help="Space-separated review terms.")
    parser.add_argument(
        "--course",
        default="",
        help="Optional case-insensitive substring required in the relative path.",
    )
    parser.add_argument("--limit", type=int, default=4, help="Maximum results.")
    parser.add_argument(
        "--format",
        choices=("text", "json"),
        default="text",
        help="Output format.",
    )
    return parser.parse_args()


def normalize(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower())


def tokens(value: str) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for token in TOKEN_PATTERN.findall(value.lower()):
        if len(token) < 2 or token in STOP_WORDS or token in seen:
            continue
        seen.add(token)
        result.append(token)
    return result


def frontmatter(lines: list[str]) -> tuple[list[str], int]:
    if not lines or lines[0].strip() != "---":
        return [], 0
    for index in range(1, len(lines)):
        if lines[index].strip() == "---":
            return lines[1:index], index + 1
    return [], 0


def metadata_value(frontmatter_lines: list[str], key: str) -> str:
    values: list[str] = []
    collecting_list = False
    for line in frontmatter_lines:
        key_match = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if key_match:
            collecting_list = key_match.group(1).lower() == key.lower()
            if collecting_list and key_match.group(2).strip():
                values.append(key_match.group(2).strip().strip("\"'[]"))
            continue
        if collecting_list:
            list_match = re.match(r"^\s*-\s*(.+?)\s*$", line)
            if list_match:
                values.append(list_match.group(1).strip().strip("\"'"))
                continue
            if line and not line[0].isspace():
                collecting_list = False
    return ", ".join(value for value in values if value)


def document_title(lines: list[str], body_start: int, file_path: Path) -> str:
    for line in lines[body_start:]:
        if line.startswith("# "):
            return line[2:].strip()
    return file_path.stem


def section_ranges(lines: list[str]) -> list[dict[str, Any]]:
    headings: list[tuple[int, int, str]] = []
    for index, line in enumerate(lines):
        match = HEADING_PATTERN.match(line)
        if match:
            headings.append((index, len(match.group(1)), match.group(2).strip()))

    sections: list[dict[str, Any]] = []
    for heading_index, (start, level, title) in enumerate(headings):
        canonical = FOCUS_SECTIONS.get(normalize(title))
        if not canonical:
            continue
        end = len(lines)
        for next_start, next_level, _ in headings[heading_index + 1 :]:
            if canonical == "One-Line Takeaway" or next_level <= level:
                end = next_start
                break
        sections.append(
            {
                "name": canonical,
                "start_line": start + 1,
                "end_line": end,
                "text": "\n".join(lines[start + 1 : end]),
            }
        )
    return sections


def term_score(term: str, value: str, weight: int, cap: int = 4) -> int:
    return min(value.count(term), cap) * weight


def rank_document(
    file_path: Path, root: Path, query_terms: list[str], query: str
) -> dict[str, Any] | None:
    try:
        text = file_path.read_text(encoding="utf-8")
    except (OSError, UnicodeError):
        return None

    lines = text.splitlines()
    frontmatter_lines, body_start = frontmatter(lines)
    title = document_title(lines, body_start, file_path)
    topics = metadata_value(frontmatter_lines, "topic")
    status = metadata_value(frontmatter_lines, "status")
    course = metadata_value(frontmatter_lines, "course")
    sections = section_ranges(lines)

    relative_path = str(file_path.relative_to(root))
    title_path = normalize(f"{title} {relative_path}")
    metadata = normalize(f"{topics} {status} {course} {' '.join(frontmatter_lines)}")
    focus_text = normalize(" ".join(section["text"] for section in sections))
    body_text = normalize(text)

    score = 0
    matched_terms: list[str] = []
    for term in query_terms:
        term_matches = (
            term_score(term, title_path, 8)
            + term_score(term, metadata, 5)
            + term_score(term, focus_text, 3)
            + term_score(term, body_text, 1)
        )
        if term_matches:
            matched_terms.append(term)
            score += term_matches

    normalized_query = normalize(query)
    if normalized_query and normalized_query in body_text:
        score += 12

    if query_terms and score == 0:
        return None

    modified_timestamp = file_path.stat().st_mtime
    return {
        "score": score,
        "path": str(file_path),
        "relative_path": relative_path,
        "title": title,
        "topics": topics,
        "status": status,
        "modified": datetime.fromtimestamp(modified_timestamp).isoformat(
            timespec="seconds"
        ),
        "modified_timestamp": modified_timestamp,
        "matched_terms": matched_terms,
        "focus_sections": [
            {
                "name": section["name"],
                "start_line": section["start_line"],
                "end_line": section["end_line"],
            }
            for section in sections
        ],
    }


def find_notes(
    root: Path, query: str, course_filter: str, limit: int
) -> tuple[int, list[dict[str, Any]]]:
    query_terms = tokens(query)
    course_filter = normalize(course_filter)
    scanned = 0
    ranked: list[dict[str, Any]] = []

    for file_path in root.rglob("*.md"):
        if any(part.startswith(".") for part in file_path.relative_to(root).parts):
            continue
        relative_path = normalize(str(file_path.relative_to(root)))
        if course_filter and course_filter not in relative_path:
            continue
        scanned += 1
        candidate = rank_document(file_path, root, query_terms, query)
        if candidate:
            ranked.append(candidate)

    ranked.sort(
        key=lambda item: (
            item["score"],
            item["modified_timestamp"],
            item["relative_path"],
        ),
        reverse=True,
    )
    return scanned, ranked[: max(limit, 0)]


def text_output(
    root: Path, query: str, scanned: int, results: list[dict[str, Any]]
) -> str:
    output = [
        f"root: {root}",
        f"query: {query or '(latest notes)'}",
        f"scanned: {scanned}",
        f"matched: {len(results)}",
    ]
    for rank, result in enumerate(results, start=1):
        output.extend(
            [
                "",
                f"{rank}. score={result['score']} {result['relative_path']}",
                f"   title: {result['title']}",
                f"   topics: {result['topics'] or '(none)'}",
                f"   status: {result['status'] or '(none)'}",
                f"   modified: {result['modified']}",
                f"   matched_terms: {', '.join(result['matched_terms']) or '(none)'}",
            ]
        )
        for section in result["focus_sections"]:
            output.append(
                "   section: "
                f"{section['name']} {section['start_line']}-{section['end_line']}"
            )
    return "\n".join(output)


def main() -> int:
    args = parse_args()
    root = args.root.expanduser().resolve()
    if not root.is_dir():
        raise SystemExit(f"lecture root not found: {root}")
    scanned, results = find_notes(root, args.query, args.course, args.limit)

    if args.format == "json":
        print(
            json.dumps(
                {
                    "root": str(root),
                    "query": args.query,
                    "scanned": scanned,
                    "matched": len(results),
                    "results": results,
                },
                ensure_ascii=False,
                indent=2,
            )
        )
    else:
        print(text_output(root, args.query, scanned, results))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
