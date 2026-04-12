#!/usr/bin/env bash
# memory-session-start.sh — SessionStart hook
# Injects daily log context and memory status into the session.
# Project-aware: loads project-specific daily log based on CWD.

set -euo pipefail
source "$HOME/.claude/hooks/memory-lib.sh"

# --- Auto-sync: pull latest from remote (3s network timeout) ---
(
  cd "$HOME/.claude"
  git rebase --abort 2>/dev/null || true
  git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=3 pull --rebase --autostash origin main 2>/dev/null || {
    git rebase --abort 2>/dev/null || true
  }
) &>/dev/null || true

MEM_DIR=$(get_memory_dir)
ensure_dirs "$MEM_DIR"

# --- Hook Health Check (장애 24h 내 탐지) ---
_HEALTH_WARNINGS=""
for _hk in memory-post-tool.py memory-session-end.sh memory-stop-guard.sh governance-guard.sh; do
  _hpath="$HOME/.claude/hooks/$_hk"
  [ ! -f "$_hpath" ] && _HEALTH_WARNINGS+="MISSING: $_hk\n"
done
_HK_EVENTS=$(python3 -c "import json; print(len(json.load(open('$HOME/.claude/settings.json')).get('hooks',{})))" 2>/dev/null || echo "0")
[ "$_HK_EVENTS" -lt 5 ] && _HEALTH_WARNINGS+="HOOKS_INCOMPLETE: settings.json에 ${_HK_EVENTS}개 이벤트만 등록\n"
# Check if last session had captures (skip on first session of the day)
_LAST_MARKER="$MEM_DIR/sessions/.last-session-ts"
if [ -f "$_LAST_MARKER" ]; then
  _CAP_TODAY="$MEM_DIR/daily/.captures-$(today).jsonl"
  _CAP_YEST="$MEM_DIR/daily/.captures-$(yesterday).jsonl"
  if [ ! -f "$_CAP_TODAY" ] && [ ! -f "$_CAP_YEST" ]; then
    _HEALTH_WARNINGS+="NO_RECENT_CAPTURES: 최근 세션에서 도구 캡처 없음 — memory-post-tool.py 확인 필요\n"
  fi
fi
if [ -n "$_HEALTH_WARNINGS" ]; then
  CONTEXT+="⚠️ HOOK HEALTH CHECK:
$(echo -e "$_HEALTH_WARNINGS")
"
fi

TODAY=$(today)
YESTERDAY=$(yesterday)
PROJECT=$(detect_project)

# --- Auto-create today's daily log if missing ---
TODAY_FILENAME=$(daily_log_filename "$TODAY")
TODAY_LOG_FILE="$MEM_DIR/daily/${TODAY_FILENAME}"
if [ ! -f "$TODAY_LOG_FILE" ]; then
  if [ "$PROJECT" = "global" ]; then
    echo "# Daily Log: ${TODAY}" > "$TODAY_LOG_FILE"
  else
    echo "# Daily Log: ${TODAY} [${PROJECT}]" > "$TODAY_LOG_FILE"
  fi
fi

CONTEXT=""

# --- Active Context Hygiene (stale/empty detection) ---
ACTIVE_DIR="$MEM_DIR/active"
ARCHIVE_DIR="$MEM_DIR/archive/active"
if [ -d "$ACTIVE_DIR" ]; then
  HYGIENE_WARNINGS=""
  for ac_file in "$ACTIVE_DIR"/*.md; do
    [ -f "$ac_file" ] || continue
    ac_basename=$(basename "$ac_file")
    # Skip non-branch contexts (e.g., date-based like 20260406.md)
    # Check: empty Changed Files (no real changes)
    changed_count=$(grep -cE '^[a-zA-Z]' <(sed -n '/^### Changed Files$/,/^```$/{ /^```$/d; /^### Changed Files$/d; p; }' "$ac_file") 2>/dev/null || echo "0")
    changed_count=$(echo "$changed_count" | tr -d '[:space:]')
    changed_count="${changed_count:-0}"
    # Check: last modified > 3 days ago
    if [ "$(uname)" = "Darwin" ]; then
      file_mtime=$(stat -f %m "$ac_file" 2>/dev/null || echo "0")
    else
      file_mtime=$(stat -c %Y "$ac_file" 2>/dev/null || echo "0")
    fi
    now_ts=$(date +%s)
    age_days=$(( (now_ts - file_mtime) / 86400 ))
    if [ "$changed_count" -eq 0 ] && [ "$age_days" -ge 3 ]; then
      HYGIENE_WARNINGS+="- ${ac_basename}: 변경 0개 + ${age_days}일 미갱신 (삭제 권장)\n"
    elif [ "$age_days" -ge 7 ]; then
      HYGIENE_WARNINGS+="- ${ac_basename}: ${age_days}일 미갱신 (archive 이동 권장)\n"
    fi
  done
  # Count active contexts
  ac_total=$(find "$ACTIVE_DIR" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$ac_total" -gt 5 ]; then
    HYGIENE_WARNINGS+="- Active context ${ac_total}개 (권장: 3개 이하). 완료된 브랜치 정리 필요\n"
  fi
  if [ -n "$HYGIENE_WARNINGS" ]; then
    CONTEXT+="⚠️ Active Context Hygiene:
$(echo -e "$HYGIENE_WARNINGS")
"
  fi
fi

# --- Active Context Recovery Chain (branch-based first, then project-based fallback) ---
CONTEXT_FILENAME=$(active_context_filename)
CONTEXT_FILE=""
if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  _BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [ -n "$_BRANCH" ] && [ "$_BRANCH" != "HEAD" ] && [ "$_BRANCH" != "main" ] && [ "$_BRANCH" != "master" ] && [ "$_BRANCH" != "develop" ]; then
    _SLUG=$(branch_slug "$_BRANCH")
    _BRANCH_FILE="$MEM_DIR/active/${_SLUG}.md"
    [ -f "$_BRANCH_FILE" ] && [ -s "$_BRANCH_FILE" ] && CONTEXT_FILE="$_BRANCH_FILE"
  fi
fi
if [ -z "$CONTEXT_FILE" ]; then
  CONTEXT_FILE="$MEM_DIR/sessions/${CONTEXT_FILENAME}"
fi
CONTEXT_LOADED="false"

if [ -f "$CONTEXT_FILE" ] && [ -s "$CONTEXT_FILE" ]; then
  if is_context_fresh "$CONTEXT_FILE" 24; then
    # Priority 1: Fresh active context (<24h) — full load
    CONTEXT+="# Active Context (Resume — 이전 작업 이어서 진행하세요)
$(safe_read_context "$CONTEXT_FILE")

"
    CONTEXT_LOADED="fresh"
  else
    # Priority 2: Stale active context (>24h) — Goal+Handoff+Next only
    GOAL=$(sed -n '/^## Goal$/,/^## /{ /^## Goal$/d; /^## /d; p; }' "$CONTEXT_FILE" | head -3)
    HANDOFF=$(sed -n '/^## Handoff$/,/^## /{ /^## Handoff$/d; /^## /d; p; }' "$CONTEXT_FILE" | head -5)
    NEXT=$(sed -n '/^## Next$/,/^## /{ /^## Next$/d; /^## /d; p; }' "$CONTEXT_FILE" | head -5)
    if [ -n "$GOAL" ] || [ -n "$HANDOFF" ] || [ -n "$NEXT" ]; then
      CONTEXT+="# Active Context (Stale — >24h, 상태 확인 후 이어가세요)
## Goal
${GOAL}
## Handoff
${HANDOFF}
## Next
${NEXT}

"
    fi
    CONTEXT_LOADED="stale"
  fi
fi

# --- Fresh start flag check (/new command) ---
FRESH_START_FLAG="$MEM_DIR/sessions/.fresh-start"
IS_FRESH_START=false
if [ -f "$FRESH_START_FLAG" ]; then
  IS_FRESH_START=true
  rm -f "$FRESH_START_FLAG"
fi

# --- /clear detection: warn if previous session left daily log empty ---
SESSION_MARKER="$MEM_DIR/sessions/.last-session-ts"
if [ -f "$SESSION_MARKER" ]; then
  MARKER_TS=$(cat "$SESSION_MARKER" 2>/dev/null || echo "0")
  NOW_TS=$(date +%s)
  ELAPSED=$(( NOW_TS - MARKER_TS ))
  # If last session was within 4 hours → likely a /clear, not a fresh start
  if [ "$ELAPSED" -lt 14400 ]; then
    # --- Session Digest: load previous conversation summary ---
    if [ "$IS_FRESH_START" = false ]; then
      LAST_JSONL_MARKER="$MEM_DIR/sessions/.last-session-jsonl"
      if [ -f "$LAST_JSONL_MARKER" ]; then
        LAST_JSONL=$(cat "$LAST_JSONL_MARKER" 2>/dev/null)
        if [ -n "$LAST_JSONL" ] && [ -f "$LAST_JSONL" ]; then
          # Defense-in-depth: reduce digest if active context is rich
          DIGEST_MAX=50
          if [ "$CONTEXT_LOADED" = "fresh" ]; then
            CONTEXT_LINES=$(line_count "$CONTEXT_FILE")
            if [ "$CONTEXT_LINES" -gt 10 ]; then
              DIGEST_MAX=25
            fi
          fi
          DIGEST=$(python3 "$HOME/.claude/hooks/session-digest.py" "$LAST_JSONL" --max-lines "$DIGEST_MAX" 2>/dev/null || true)
          if [ -n "$DIGEST" ] && [ "$(echo "$DIGEST" | wc -l | tr -d ' ')" -gt 3 ]; then
            CONTEXT="## 이전 대화 요약 (자동 생성)
${DIGEST}

${CONTEXT}"
          fi
        fi
        rm -f "$LAST_JSONL_MARKER"
      fi
    fi
    # Check if daily log has real content (not just header)
    LOG_CONTENT_LINES=0
    if [ -f "$TODAY_LOG_FILE" ]; then
      LOG_CONTENT_LINES=$(grep -cvE '^\s*$|^# Daily Log:|Compaction Checkpoint|컴팩션|자동 컴팩션|세션 재개 후' "$TODAY_LOG_FILE" 2>/dev/null || true)
      LOG_CONTENT_LINES=$(echo "$LOG_CONTENT_LINES" | tr -d '[:space:]')
      LOG_CONTENT_LINES="${LOG_CONTENT_LINES:-0}"
    fi
    if [ "$LOG_CONTENT_LINES" -lt 2 ]; then
      if [ "$CONTEXT_LOADED" != "false" ]; then
        # Active context exists but daily log is empty
        CONTEXT+="⚠️ /clear 감지: daily log가 비어있습니다. 이전 세션 작업 내용을 daily log에 기록해주세요.
경로: ${TODAY_LOG_FILE}
포맷: ### HH:MM - 작업 제목

"
      else
        # No active context and no daily log
        CONTEXT+="⚠️ /clear 감지: 이전 세션 컨텍스트가 없습니다.
위 Previous session summary를 기반으로 active context를 작성해주세요.

경로: $MEM_DIR/sessions/${CONTEXT_FILENAME}
포맷:
---
project: ${PROJECT}
updated: $(date +%Y-%m-%dT%H:%M+09:00)
---
## Goal
{이전 세션 목표}
## Status
{완료/미완료 항목}
## Next
{다음 할 일}
## Key Decisions
{주요 결정사항}
## Handoff
- 바뀐 것: {변경 사항}
- 안 된 것: {미완료}
- 다음 파일: {파일 경로}
- 남은 위험: {이슈}

"
      fi
    fi
  fi
fi

# Update session marker
date +%s > "$SESSION_MARKER"

# Generate stable session ID for edit-tracker ↔ session-end coordination
# PPID is unreliable across async hooks — use a file-based ID instead
SESSION_ID_FILE="$MEM_DIR/sessions/.current-session-id"
PREVIOUS_ID_FILE="$MEM_DIR/sessions/.previous-session-id"
# Preserve previous session ID before overwriting (fixes async SessionEnd race)
if [ -f "$SESSION_ID_FILE" ]; then
  cp "$SESSION_ID_FILE" "$PREVIOUS_ID_FILE"
fi
SESSION_ID="session-$(date +%s)-$$"
echo "$SESSION_ID" > "$SESSION_ID_FILE"

# --- Session metadata (CWD, git branch) ---
CURRENT_TIME=$(date +%H:%M)
CONTEXT+="# Session: ${TODAY}
- CWD: ${PWD}
- Project: ${PROJECT}
- Current time (KST): ${CURRENT_TIME}
- IMPORTANT: Always use KST (UTC+9) for daily log timestamps. Run 'date +%H:%M' to get current KST time before writing timestamps.
"
if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  CONTEXT+="- Branch: ${BRANCH}
"
fi
CONTEXT+="
"

# --- Load today's project daily log (max 50 lines) ---
if [ -f "$TODAY_LOG_FILE" ] && [ -s "$TODAY_LOG_FILE" ]; then
  CONTEXT+="# Daily Log: ${TODAY} [${PROJECT}]
$(safe_read_limited "$TODAY_LOG_FILE" 50)

"
fi

# --- Load yesterday's project daily log (budget-aware, max 20 lines) ---
YESTERDAY_FILENAME=$(daily_log_filename "$YESTERDAY")
YESTERDAY_LOG="$MEM_DIR/daily/${YESTERDAY_FILENAME}"
CURRENT_LINES=$(echo "$CONTEXT" | wc -l | tr -d ' ')
if [ "$CURRENT_LINES" -lt 150 ] && [ -f "$YESTERDAY_LOG" ] && [ -s "$YESTERDAY_LOG" ]; then
  CONTEXT+="# Daily Log: ${YESTERDAY} [${PROJECT}] (yesterday)
$(safe_read_limited "$YESTERDAY_LOG" 20)

"
fi

# --- [PROMOTE] auto-detection from yesterday's log ---
if [ -f "$YESTERDAY_LOG" ]; then
  PROMOTE_COUNT=$(grep -c '^\- \[PROMOTE\]' "$YESTERDAY_LOG" 2>/dev/null || true)
  PROMOTE_COUNT=$(echo "$PROMOTE_COUNT" | tr -d '[:space:]')
  PROMOTE_COUNT="${PROMOTE_COUNT:-0}"
  if [ "$PROMOTE_COUNT" -gt 0 ]; then
    CONTEXT+="ACTION NEEDED: ${PROMOTE_COUNT} [PROMOTE] item(s) in yesterday's Daily Log (${YESTERDAY}) awaiting promotion to MEMORY.md.
"
  fi
fi

# --- Check MEMORY.md line count ---
MEMORY_FILE="$MEM_DIR/MEMORY.md"
if [ -f "$MEMORY_FILE" ]; then
  LINES=$(line_count "$MEMORY_FILE")
  if [ "$LINES" -gt 150 ]; then
    CONTEXT+="WARNING: MEMORY.md is ${LINES} lines (soft limit: 150). Consider moving detailed content to memory/topics/*.md files.

"
  fi
fi

# --- List available topic files ---
TOPICS_DIR="$MEM_DIR/topics"
if [ -d "$TOPICS_DIR" ]; then
  TOPIC_FILES=$(find "$TOPICS_DIR" -name "*.md" -type f 2>/dev/null | sort)
  if [ -n "$TOPIC_FILES" ]; then
    CONTEXT+="Available topic files (read on demand with Read tool):
"
    while IFS= read -r f; do
      CONTEXT+="- memory/topics/$(basename "$f")
"
    done <<< "$TOPIC_FILES"
    CONTEXT+="
"
  fi
fi

# --- Recovery fallback: no context at all ---
if [ "$CONTEXT_LOADED" = false ]; then
  DAILY_HAS_CONTENT=false
  if [ -f "$TODAY_LOG_FILE" ]; then
    DL_LINES=$(grep -cvE '^\s*$|^# Daily Log:|Compaction Checkpoint|컴팩션|자동 컴팩션|세션 재개 후' "$TODAY_LOG_FILE" 2>/dev/null || true)
    DL_LINES=$(echo "$DL_LINES" | tr -d '[:space:]')
    DL_LINES="${DL_LINES:-0}"
    [ "$DL_LINES" -ge 2 ] && DAILY_HAS_CONTENT=true
  fi
  if [ "$DAILY_HAS_CONTENT" = false ]; then
    CONTEXT+="ℹ️ 이전 세션 컨텍스트 없음. memory_search(query)로 관련 메모리를 검색하세요.

"
  fi
fi

# --- Friction queue from previous session ---
FRICTION_QUEUE="$MEM_DIR/sessions/.friction-queue"
if [ -f "$FRICTION_QUEUE" ] && [ -s "$FRICTION_QUEUE" ]; then
  CONTEXT+="
⚠️ 이전 세션 삽질 패턴 감지:
"
  while IFS= read -r line; do
    F_COUNT=$(echo "$line" | awk '{print $1}')
    F_PATH=$(echo "$line" | awk '{print $2}')
    CONTEXT+="- $(basename "$F_PATH"): ${F_COUNT}회 반복 편집
"
  done < "$FRICTION_QUEUE"
  CONTEXT+="failure-log.md에 '미분류' 상태로 자동 기록됨.
⏸️ 작업 시작 전에 failure-log.md의 '미분류' 엔트리를 분류하세요:
1. Read memory/topics/failure-log.md
2. '미분류' 행의 원인을 Prompt/Context/Harness 중 택1로 변경
3. 해법 컬럼에 재발 방지책 기록
(1분이면 됩니다. 이것이 하네스 자기 진화의 핵심 루프입니다)

"
  rm -f "$FRICTION_QUEUE"
fi

# --- Improvement suggestions from previous session's self-absorb ---
SUGGESTIONS="$MEM_DIR/sessions/.improvement-suggestions.md"
if [ -f "$SUGGESTIONS" ] && [ -s "$SUGGESTIONS" ]; then
  CONTEXT+="
📋 이전 세션 Self-Absorb 개선 제안:
$(cat "$SUGGESTIONS")

위 제안을 검토하고 적용 여부를 결정하세요. 적용 완료 후 파일을 삭제합니다.

"
fi

# --- Auto-promote [PROMOTE] items from daily logs ---
# (absorbed from memory-promote-analyzer.sh)
if [ -d "$MEM_DIR/daily" ] && [ -f "$MEM_DIR/MEMORY.md" ]; then
  _PROMOTED=0
  for _dfile in "$MEM_DIR/daily"/*.md; do
    [ -f "$_dfile" ] || continue
    while IFS= read -r _line; do
      _content=""
      if [[ "$_line" =~ ^-\ \[PROMOTE\]\ (.+)$ ]]; then _content="${BASH_REMATCH[1]}"
      elif [[ "$_line" =~ ^\[PROMOTE\]\ (.+)$ ]]; then _content="${BASH_REMATCH[1]}"
      else continue; fi
      grep -qF "$_content" "$MEM_DIR/MEMORY.md" 2>/dev/null && continue
      if [ "$_PROMOTED" -eq 0 ]; then
        echo "" >> "$MEM_DIR/MEMORY.md"
        echo "### Promoted $(today)" >> "$MEM_DIR/MEMORY.md"
      fi
      echo "- $_content" >> "$MEM_DIR/MEMORY.md"
      _PROMOTED=$((_PROMOTED + 1))
    done < "$_dfile"
    [ "$_PROMOTED" -gt 0 ] && sed -i '' 's/\[PROMOTE\]/[PROMOTED]/g' "$_dfile" 2>/dev/null || true
  done
  [ "$_PROMOTED" -gt 0 ] && CONTEXT+="${_PROMOTED} item(s) auto-promoted to MEMORY.md.
"
fi

# --- Codex activity summary (today, compact) ---
CODEX_SUMMARY=$(python3 "$HOME/.claude/scripts/codex-harvest.py" --date "$TODAY" --json 2>/dev/null || true)
if [ -n "$CODEX_SUMMARY" ] && [ "$CODEX_SUMMARY" != "[]" ]; then
  CODEX_STATS=$(python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
if not data: sys.exit(0)
projects = {}
for s in data:
    p = s['project']
    projects.setdefault(p, {'sessions': 0, 'tools': 0, 'files': set()})
    projects[p]['sessions'] += 1
    projects[p]['tools'] += s['tool_call_count']
    projects[p]['files'].update(s['files_touched'])
lines = []
for p, v in sorted(projects.items(), key=lambda x: -x[1]['tools']):
    lines.append(f'- **{p}**: {v[\"sessions\"]}s/{v[\"tools\"]}t/{len(v[\"files\"])}f')
total_s = sum(v['sessions'] for v in projects.values())
total_t = sum(v['tools'] for v in projects.values())
total_f = len({f for v in projects.values() for f in v['files']})
lines.append(f'Total: {total_s} sessions, {total_t} tools, {total_f} files. Run: codex-harvest.py --date $TODAY for details')
print('\n'.join(lines))
" <<< "$CODEX_SUMMARY" 2>/dev/null || true)
  if [ -n "$CODEX_STATS" ]; then
    CONTEXT+="# Codex Activity (${TODAY})
${CODEX_STATS}

"
  fi
fi

# --- Semantic search availability (MCP-based) ---
CONTEXT+="Semantic memory search available via memory-search MCP: use memory_search(query) tool for hybrid BM25+Vector search across all memory files.
"

# --- Memory system reminder (project-aware path) ---
if [ -n "$CONTEXT" ]; then
  CONTEXT+="Memory system active: Write important decisions, debugging insights, and patterns to memory/daily/${TODAY_FILENAME} during this session. Use [PROMOTE] tag for items that should be promoted to MEMORY.md."
fi

# Output context (plain text — Claude Code captures stdout)
if [ -n "$CONTEXT" ]; then
  echo "$CONTEXT"
fi

exit 0
