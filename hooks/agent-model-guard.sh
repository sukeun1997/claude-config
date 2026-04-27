#!/usr/bin/env bash
# agent-model-guard.sh — PreToolUse Agent hook
# §3 Model Routing 준수 강제: Explore=haiku, writer=haiku 등
# W17 review: Explore 17/36건 model=default → haiku 미지정

set -euo pipefail

# TOOL_INPUT contains the Agent call JSON
INPUT="${TOOL_INPUT:-}"
[ -z "$INPUT" ] && exit 0

# Extract subagent_type (or description for heuristic matching)
SUBAGENT=$(echo "$INPUT" | grep -o '"subagent_type"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"subagent_type"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//')
MODEL=$(echo "$INPUT" | grep -o '"model"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"model"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//')

# Only check agents that have a required model tier
case "${SUBAGENT,,}" in
  explore|writer|style-reviewer)
    if [ -z "$MODEL" ] || [ "$MODEL" = "default" ] || [ "$MODEL" = "sonnet" ] || [ "$MODEL" = "opus" ]; then
      echo "§3 Model Routing: ${SUBAGENT}는 haiku 티어입니다. model: \"haiku\"를 지정하세요."
    fi
    ;;
esac

exit 0
