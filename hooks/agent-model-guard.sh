#!/usr/bin/env bash
# agent-model-guard.sh — PreToolUse Agent|Task hook
# §3 Model Routing 준수 강제: Explore=haiku, writer=haiku 등
# W17 review: Explore 17/36건 model=default → haiku 미지정
# 2026-07-11: stdin JSON 입력(현행 훅 API)으로 전환 + exit 2 소프트 차단으로 모델에 재호출 유도

set -euo pipefail

# Hook input arrives as JSON on stdin: {"tool_name":..., "tool_input":{...}}
INPUT=$(cat 2>/dev/null || true)
[ -z "$INPUT" ] && exit 0

# Extract subagent_type and model (|| true for set -e safety when field is absent)
SUBAGENT=$(echo "$INPUT" | grep -o '"subagent_type"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"subagent_type"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//' || true)
MODEL=$(echo "$INPUT" | grep -o '"model"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"model"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//' || true)

# Only check agents that have a required model tier (tr for bash 3.2 compat)
SUBAGENT_LOWER=$(echo "$SUBAGENT" | tr '[:upper:]' '[:lower:]')
case "$SUBAGENT_LOWER" in
  explore|writer|style-reviewer)
    if [ -z "$MODEL" ] || [ "$MODEL" = "default" ] || [ "$MODEL" = "sonnet" ] || [ "$MODEL" = "opus" ]; then
      # exit 2: 호출 차단 + stderr가 모델에 전달됨 → model: "haiku"로 재호출 유도
      echo "§3 Model Routing: ${SUBAGENT}는 haiku 티어입니다. model: \"haiku\"를 지정하여 다시 호출하세요." >&2
      exit 2
    fi
    ;;
esac

exit 0
