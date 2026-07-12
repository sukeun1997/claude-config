#!/usr/bin/env python3
"""subagent-result-tracker.py — SubagentStop hook

async Agent 호출의 result 공백 보완 (2026-07-12 재시작 검증에서 발견).
memory-post-tool.py는 PostToolUse가 launch 시점(출력 없음)에 발화하여
agent-usage jsonl에 result=""로 기록된다. 이 훅이 서브에이전트 종료 시점에
last_assistant_message에서 Structured Response Contract
(결과: SUCCESS|PARTIAL|FAILED)를 추출해 해당 레코드를 갱신한다.

입력 (stdin JSON): session_id, transcript_path, agent_id, agent_type,
last_assistant_message (docs.claude.com/en/docs/claude-code/hooks)
출력: 없음 (조용히 성공/실패). 어떤 경우에도 exit 0 — 차단 금지.
"""

import fcntl
import json
import re
import sys
from datetime import datetime
from pathlib import Path

RESULT_RE = re.compile(r"결과\**\s*[:：]\s*\**\s*(SUCCESS|PARTIAL|FAILED)")
SCAN_LIMIT = 100  # 파일 끝에서 매칭 후보로 스캔할 최대 레코드 수


def extract_text(msg):
    """last_assistant_message가 str 또는 message dict 양쪽 형태를 허용."""
    if isinstance(msg, str):
        return msg
    if isinstance(msg, dict):
        content = msg.get("content", msg.get("message", {}).get("content", ""))
        if isinstance(content, str):
            return content
        if isinstance(content, list):
            return "\n".join(c.get("text", "") for c in content if isinstance(c, dict))
    return ""


def load_description(data):
    """subagents/agent-<id>.meta.json에서 description을 읽어 매칭 정밀도를 높인다 (없으면 빈 값)."""
    agent_id = data.get("agent_id", "")
    tp = data.get("transcript_path", "")
    if not agent_id or not tp:
        return ""
    meta = Path(tp).with_suffix("") / "subagents" / f"agent-{agent_id}.meta.json"
    try:
        return json.loads(meta.read_text()).get("description", "")
    except (OSError, ValueError):
        return ""


def main():
    try:
        data = json.load(sys.stdin)
    except (ValueError, OSError):
        return
    text = extract_text(data.get("last_assistant_message", ""))
    if not text:
        return
    m = RESULT_RE.search(text)
    if not m:
        return
    result = m.group(1)
    agent_type = (data.get("agent_type") or "").strip()
    description = load_description(data)[:80].replace("\n", " ").strip()

    month = datetime.now().strftime("%Y-%m")
    usage = Path.home() / ".claude" / "memory" / "metrics" / f"agent-usage-{month}.jsonl"
    if not usage.exists():
        return
    try:
        with open(usage, "r+", encoding="utf-8") as f:
            fcntl.flock(f, fcntl.LOCK_EX)
            rows = f.read().splitlines()
            # 끝에서부터: result 키가 있고 비어 있는 레코드 중 agent(+description) 일치 항목 갱신
            candidates = range(len(rows) - 1, max(len(rows) - SCAN_LIMIT, 0) - 1, -1)
            target = -1
            for i in candidates:
                try:
                    r = json.loads(rows[i])
                except ValueError:
                    continue
                if "result" not in r or r.get("result"):
                    continue
                if agent_type and r.get("agent", "").lower() != agent_type.lower():
                    continue
                if description and r.get("description") == description:
                    target = i
                    break  # 정확 매치 즉시 확정
                if target == -1:
                    target = i  # agent 일치 최신 레코드를 fallback으로 유지
            if target == -1:
                return
            r = json.loads(rows[target])
            r["result"] = result
            rows[target] = json.dumps(r, ensure_ascii=False)
            f.seek(0)
            f.truncate()
            f.write("\n".join(rows) + "\n")
    except (OSError, ValueError, UnicodeError):
        return  # 어떤 실패에도 조용히 종료 — 서브에이전트 흐름 차단 금지


if __name__ == "__main__":
    main()
    sys.exit(0)
