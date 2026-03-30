#!/usr/bin/env python3
"""session-digest.py — Parse Claude Code session JSONL into conversation digest.

Usage: python3 session-digest.py <jsonl_path> [--max-lines 80]
Output: Conversation digest to stdout (empty on error/no content)
"""

import json
import re
import sys
from pathlib import Path


# Secret patterns to mask
SECRET_PATTERNS = [
    re.compile(r'sk-[a-zA-Z0-9]{20,}'),
    re.compile(r'ghp_[a-zA-Z0-9]{36,}'),
    re.compile(r'AKIA[A-Z0-9]{16}'),
    re.compile(r'Bearer\s+[a-zA-Z0-9._\-]{20,}'),
    re.compile(r'password["\s:=]+[^\s,]{8,}', re.IGNORECASE),
]

# Noise patterns to skip
NOISE_TAGS = [
    '<command-name>',
    '<command-message>',
    '<local-command-caveat>',
    '<system-reminder>',
    '<user-prompt-submit-hook>',
    '<command-args>',
]


def mask_secrets(text: str) -> str:
    for pat in SECRET_PATTERNS:
        text = pat.sub('[REDACTED]', text)
    return text


def is_noise(text: str) -> bool:
    stripped = text.strip()
    if len(stripped) < 3:
        return True
    for tag in NOISE_TAGS:
        if stripped.startswith(tag):
            return True
    if stripped.startswith('Base directory for this skill:'):
        return True
    return False


def truncate_message(text: str) -> str:
    """Structure-aware truncation.

    - <500 chars: full text
    - >=500 chars: first 300 + numbered list skeleton + last 150
    """
    if len(text) < 500:
        return text

    head = text[:300]
    tail = text[-150:]

    # Extract numbered list items (1. xxx, 2. xxx, etc.)
    list_items = re.findall(r'^(\d+[\.\)]\s*.{0,80})', text, re.MULTILINE)
    # Extract markdown headers
    headers = re.findall(r'^(#{1,3}\s+.{0,60})', text, re.MULTILINE)

    middle_parts = []
    if headers:
        middle_parts.extend(headers[:5])
    if list_items:
        middle_parts.extend(list_items[:10])

    if middle_parts:
        middle = '\n'.join(middle_parts)
        return f"{head}\n[...]\n{middle}\n[...]\n{tail}"
    else:
        return f"{head}\n[...]\n{tail}"


def extract_text_content(content) -> str:
    """Extract text from message content (string or list format)."""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        texts = []
        for item in content:
            if isinstance(item, dict) and item.get('type') == 'text':
                text = item.get('text', '')
                if text and not is_noise(text):
                    texts.append(text)
        return '\n'.join(texts)
    return ''


def parse_jsonl(jsonl_path: str, max_lines: int = 80) -> str:
    """Parse JSONL and return conversation digest."""
    path = Path(jsonl_path)
    if not path.exists() or path.stat().st_size == 0:
        return ''

    messages = []

    with open(path) as f:
        for line in f:
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue

            rec_type = record.get('type', '')
            if rec_type not in ('user', 'assistant'):
                continue

            msg = record.get('message', {})
            if not msg:
                continue

            role = msg.get('role', rec_type)
            content = msg.get('content', '')
            text = extract_text_content(content)

            if not text or not text.strip():
                continue
            if is_noise(text):
                continue

            text = mask_secrets(text)
            prefix = 'U' if role == 'user' else 'A'
            messages.append((prefix, text.strip()))

    if not messages:
        return ''

    # Build digest with truncation
    lines = []
    for prefix, text in messages:
        truncated = truncate_message(text)
        msg_lines = truncated.split('\n')
        lines.append(f"{prefix}: {msg_lines[0]}")
        for extra in msg_lines[1:]:
            lines.append(f"   {extra}")

    # Apply max lines limit
    output_lines = []
    count = 0
    for line in lines:
        output_lines.append(line)
        count += 1
        if count >= max_lines:
            output_lines.append(f"(... {len(lines) - count} lines truncated)")
            break

    return '\n'.join(output_lines)


def main():
    if len(sys.argv) < 2:
        sys.exit(0)

    jsonl_path = sys.argv[1]
    max_lines = 80

    if '--max-lines' in sys.argv:
        idx = sys.argv.index('--max-lines')
        if idx + 1 < len(sys.argv):
            try:
                max_lines = int(sys.argv[idx + 1])
            except ValueError:
                pass

    try:
        digest = parse_jsonl(jsonl_path, max_lines)
        if digest:
            print(digest)
    except Exception:
        # Silent failure — fallback to existing active context
        pass


if __name__ == '__main__':
    main()
