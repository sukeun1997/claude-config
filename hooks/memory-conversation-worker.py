#!/usr/bin/env python3
"""
memory-conversation-worker.py — Background conversation summarizer

Reads Claude Code transcript JSONL, extracts user/assistant dialogue,
summarizes via Gemini Flash, and appends to daily log.

Usage:
  python3 memory-conversation-worker.py \
    --transcript <path.jsonl> \
    --offset <byte-offset> \
    --daily-log <daily/YYYY-MM-DD.md> \
    --session-id <id> \
    --state-file <path.json>

Runs as a detached background process spawned by memory-conversation-summarizer.py.
"""

import argparse
import fcntl
import json
import os
import re
import sys
import time
from datetime import datetime
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

MAX_INPUT_CHARS = 8000  # 더 많은 대화를 한 번에 요약 (디바운스 늘렸으므로)
GEMINI_MODEL = "gemini-2.5-flash-lite"
GEMINI_TEMPERATURE = 0.2
GEMINI_MAX_OUTPUT_TOKENS = 400

SYSTEM_PROMPT = """개발 세션 로거. 대화에서 **장기 가치 있는 정보만** 추출.

=== 반드시 SKIP 반환 (한 단어만) ===
- 파일 읽기, 검색, 코드 탐색만 한 경우
- 빌드/컴파일 실행 과정 (성공이든 실패든 과정 자체)
- 동일 주제의 반복 진행 상황 업데이트
- 스킬/플러그인의 설명문이나 가이드라인 내용
- 단순 설정 변경, 포맷팅, 린트 수정
- "빌드 시작", "컴파일 확인", "테스트 실행" 같은 루틴 작업

=== 기록할 것 (엄격 필터링) ===
- **설계 결정 + 근거** (왜 A를 B 대신 선택했는지)
- **버그 근본 원인 + 해결책** (증상이 아닌 원인)
- **아키텍처 패턴 발견** (재사용 가능한 인사이트)
- **배포/릴리즈 중요 변경** (breaking change, 마이그레이션)

=== 규칙 ===
- 한국어, 기술 용어는 영어 유지
- 하나의 ### 블록으로 통합 (여러 블록 금지)
- 3~6줄 bullet point로 압축
- [PROMOTE] 태그는 진짜 장기 보존이 필요한 경우만 (세션당 최대 2개)
- 빌드 명령어, gradlew 명령어, 파일 경로 나열 금지

출력 포맷:
### HH:MM - [토픽 한 줄]
- bullet point (3~6개)

현재 시각: {current_time}
"""

# Transcript record types to process
PROCESS_TYPES = {"user", "assistant"}
SKIP_TYPES = {"progress", "file-history-snapshot", "system"}

# ---------------------------------------------------------------------------
# Gemini API
# ---------------------------------------------------------------------------

_client = None


def get_gemini_client():
    """Initialize Gemini client (lazy singleton)."""
    global _client
    if _client is not None:
        return _client

    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        zshrc = Path.home() / ".zshrc"
        if zshrc.exists():
            for line in zshrc.read_text().splitlines():
                m = re.match(r'^export\s+GEMINI_API_KEY[= ]"?([^"]+)"?', line)
                if m:
                    api_key = m.group(1).strip()
                    break
    if not api_key:
        print("Error: GEMINI_API_KEY not set.", file=sys.stderr)
        sys.exit(1)

    from google import genai
    _client = genai.Client(api_key=api_key)
    return _client


def summarize_with_gemini(conversation_text: str) -> str | None:
    """Call Gemini Flash to summarize conversation text.

    Returns summary string, "SKIP" if not significant, or None on error.
    """
    client = get_gemini_client()
    from google.genai import types

    current_time = datetime.now().strftime("%H:%M")
    system = SYSTEM_PROMPT.format(current_time=current_time)

    try:
        response = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=conversation_text,
            config=types.GenerateContentConfig(
                system_instruction=system,
                temperature=GEMINI_TEMPERATURE,
                max_output_tokens=GEMINI_MAX_OUTPUT_TOKENS,
            ),
        )
        return response.text.strip() if response.text else None
    except Exception as e:
        print(f"Gemini API error: {e}", file=sys.stderr)
        return None


# ---------------------------------------------------------------------------
# Transcript parsing
# ---------------------------------------------------------------------------

def extract_text_from_content(content) -> str:
    """Extract readable text from message content (string or list)."""
    if isinstance(content, str):
        return content.strip()

    if not isinstance(content, list):
        return ""

    parts = []
    for item in content:
        if not isinstance(item, dict):
            continue
        item_type = item.get("type", "")
        if item_type == "text":
            text = item.get("text", "").strip()
            if text:
                parts.append(text)
        elif item_type == "tool_use":
            name = item.get("name", "unknown")
            tool_input = item.get("input", {})
            # Brief summary of tool usage
            if name in ("Write", "Edit"):
                fp = tool_input.get("file_path", "") if isinstance(tool_input, dict) else ""
                parts.append(f"[Tool: {name} → {_shorten(fp)}]")
            elif name == "Bash":
                cmd = tool_input.get("command", "")[:80] if isinstance(tool_input, dict) else ""
                parts.append(f"[Tool: Bash → {cmd}]")
            elif name == "Task":
                desc = tool_input.get("description", "")[:60] if isinstance(tool_input, dict) else ""
                parts.append(f"[Tool: Task → {desc}]")
            # Skip Read/Grep/Glob/ToolSearch - they're noise
        elif item_type == "tool_result":
            # Tool results are typically too verbose; skip
            pass
        # Skip: thinking, progress, etc.
    return "\n".join(parts)


def _shorten(path: str) -> str:
    """Shorten file path for display."""
    if not path:
        return ""
    home = str(Path.home())
    if path.startswith(home):
        return "~" + path[len(home):]
    return path.split("/")[-1] if "/" in path else path


def parse_transcript(transcript_path: str, offset: int) -> tuple[str, int]:
    """Parse transcript JSONL from offset, return (conversation_text, new_offset).

    Groups records by message.id to avoid duplicates from streaming.
    """
    path = Path(transcript_path)
    if not path.exists():
        return "", offset

    file_size = path.stat().st_size
    if file_size <= offset:
        return "", offset

    seen_ids = set()
    turns = []

    with open(path, "r", encoding="utf-8") as f:
        f.seek(offset)
        while True:
            line = f.readline()
            if not line:
                break
            line = line.strip()
            if not line:
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue

            rec_type = record.get("type", "")
            if rec_type not in PROCESS_TYPES:
                continue

            message = record.get("message", {})
            msg_id = message.get("id", record.get("uuid", ""))

            # Deduplicate: streaming produces multiple records per message
            if msg_id and msg_id in seen_ids:
                continue
            if msg_id:
                seen_ids.add(msg_id)

            content = message.get("content", "")
            text = extract_text_from_content(content)
            if not text:
                continue

            role = "User" if rec_type == "user" else "Assistant"
            turns.append(f"**{role}**: {text}")

        new_offset = f.tell()

    conversation = "\n\n".join(turns)

    # Cap input size
    if len(conversation) > MAX_INPUT_CHARS:
        conversation = conversation[-MAX_INPUT_CHARS:]

    return conversation, new_offset


# ---------------------------------------------------------------------------
# Daily log writer
# ---------------------------------------------------------------------------

def append_to_daily_log(daily_log_path: str, summary: str) -> bool:
    """Append summary to daily log with file locking."""
    path = Path(daily_log_path)
    path.parent.mkdir(parents=True, exist_ok=True)

    try:
        with open(path, "a", encoding="utf-8") as f:
            fcntl.flock(f.fileno(), fcntl.LOCK_EX)
            try:
                f.write(summary + "\n\n")
            finally:
                fcntl.flock(f.fileno(), fcntl.LOCK_UN)
        return True
    except OSError as e:
        print(f"Error writing daily log: {e}", file=sys.stderr)
        return False


# ---------------------------------------------------------------------------
# State management
# ---------------------------------------------------------------------------

def update_state(state_file: str, new_offset: int) -> None:
    """Update state file with new offset and timestamp."""
    path = Path(state_file)
    state = {}
    if path.exists():
        try:
            state = json.loads(path.read_text())
        except (json.JSONDecodeError, OSError):
            state = {}

    state["last_offset"] = new_offset
    state["last_run_ts"] = time.time()
    state["pending_turns"] = 0

    try:
        path.write_text(json.dumps(state))
    except OSError as e:
        print(f"Error updating state: {e}", file=sys.stderr)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Conversation summarizer worker")
    parser.add_argument("--transcript", required=True, help="Path to transcript JSONL")
    parser.add_argument("--offset", type=int, default=0, help="Byte offset to start reading from")
    parser.add_argument("--daily-log", required=True, help="Path to daily log markdown file")
    parser.add_argument("--session-id", required=True, help="Session identifier")
    parser.add_argument("--state-file", required=True, help="Path to state JSON file")
    args = parser.parse_args()

    # Parse new conversation from transcript
    conversation, new_offset = parse_transcript(args.transcript, args.offset)

    if not conversation.strip():
        # Nothing new to summarize, just update offset
        update_state(args.state_file, new_offset)
        return

    # Summarize via Gemini
    summary = summarize_with_gemini(conversation)

    # Always update offset (even on error) to prevent re-processing
    update_state(args.state_file, new_offset)

    if not summary:
        return

    # "SKIP" means conversation was not significant
    if summary.strip().upper() == "SKIP":
        return

    # Ensure summary starts with ### HH:MM format
    if not summary.startswith("###"):
        current_time = datetime.now().strftime("%H:%M")
        summary = f"### {current_time} - [Conversation Summary]\n{summary}"

    append_to_daily_log(args.daily_log, summary)


if __name__ == "__main__":
    main()
