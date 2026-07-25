#!/usr/bin/env python3
"""InstructionsLoaded 실측 로그 — 지침 파일 로드 빈도를 jsonl로 적재 (/review-week 규칙 은퇴 판단 근거)."""
import datetime
import json
import os
import sys

LOG = os.path.expanduser("~/.claude/usage-data/instructions-loaded.jsonl")


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except Exception:
        return
    data["_ts"] = datetime.datetime.now().astimezone().isoformat(timespec="seconds")
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(json.dumps(data, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
