#!/usr/bin/env bash
set -euo pipefail

# ── 의존성 체크 ───────────────────────────────────
for cmd in tmux jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: '$cmd'이 설치되어 있지 않습니다." >&2
    exit 1
  fi
done

# ── 경로 설정 (CWD 기준, env var 오버라이드 가능) ──
HANDOFF_DIR="${HANDOFF_DIR:-$PWD/.handoff}"
CONFIG_FILE="$HANDOFF_DIR/config.json"
LOCK_DIR="$HANDOFF_DIR/.lock"

usage() {
  cat <<'EOF'
Usage:
  handoff.sh init [--pane PANE_ID]
  handoff.sh inject <task-id>
  handoff.sh poll <task-id> [--timeout SEC]
  handoff.sh detect-pane
  handoff.sh cancel
  handoff.sh status

Environment:
  HANDOFF_DIR   .handoff 디렉토리 경로 (기본: $PWD/.handoff)

프로젝트 무관 범용 도구. 어느 디렉토리에서든 실행 가능.
EOF
}

ensure_dirs() {
  mkdir -p "$HANDOFF_DIR/queue" "$HANDOFF_DIR/result" "$HANDOFF_DIR/review"
}

# ── Atomic lock (mkdir 기반) ──────────────────────
acquire_lock() {
  local task_id="$1"
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "$task_id" > "$LOCK_DIR/task_id"
    return 0
  else
    local existing
    existing=$(cat "$LOCK_DIR/task_id" 2>/dev/null || echo "unknown")
    echo "ERROR: 이미 진행 중인 작업이 있습니다. (task: $existing)" >&2
    return 1
  fi
}

release_lock() {
  rm -rf "$LOCK_DIR"
}

get_lock_task() {
  cat "$LOCK_DIR/task_id" 2>/dev/null || echo ""
}

# ── init ──────────────────────────────────────────
cmd_init() {
  local pane_id=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --pane) pane_id="$2"; shift 2 ;;
      *) pane_id="$1"; shift ;;
    esac
  done
  ensure_dirs

  if [ -z "$pane_id" ]; then
    pane_id=$(cmd_detect_pane)
    if [ -z "$pane_id" ]; then
      echo "ERROR: Codex pane을 자동 감지할 수 없습니다. --pane <PANE_ID>를 지정하세요." >&2
      exit 1
    fi
  fi

  cat > "$CONFIG_FILE" <<EOJSON
{
  "codex_pane": "$pane_id",
  "poll_interval_sec": 5,
  "poll_timeout_sec": 300,
  "max_review_rounds": 2,
  "prompt_pattern": "(>|❯|\\\\$)\\\\s*$"
}
EOJSON
  echo "OK: config 생성 완료 (pane=$pane_id, dir=$HANDOFF_DIR)"
}

# ── detect-pane ───────────────────────────────────
cmd_detect_pane() {
  local current_pane
  current_pane=$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)

  # 현재 세션의 pane 중 자신이 아닌 pane 찾기 (node/codex 우선)
  local candidate
  candidate=$(tmux list-panes -s -F '#{pane_id} #{pane_current_command}' 2>/dev/null \
    | grep -v "^${current_pane}" \
    | grep -iE 'node|codex' \
    | head -1 \
    | awk '{print $1}')

  if [ -n "$candidate" ]; then
    echo "$candidate"
    return 0
  fi

  # fallback: 자신이 아닌 첫 번째 pane
  candidate=$(tmux list-panes -s -F '#{pane_id}' 2>/dev/null \
    | grep -v "^${current_pane}" \
    | head -1)
  echo "$candidate"
}

# ── inject ────────────────────────────────────────
cmd_inject() {
  local task_id="$1"
  local task_file="$HANDOFF_DIR/queue/task-${task_id}.md"

  if [ ! -f "$task_file" ]; then
    echo "ERROR: $task_file 가 없습니다." >&2
    exit 1
  fi

  if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: config.json이 없습니다. 먼저 'handoff.sh init'을 실행하세요." >&2
    exit 1
  fi

  local codex_pane
  codex_pane=$(jq -r '.codex_pane' "$CONFIG_FILE")
  local prompt_pattern
  prompt_pattern=$(jq -r '.prompt_pattern' "$CONFIG_FILE")

  # Atomic lock
  acquire_lock "$task_id" || exit 1

  # Codex pane의 CWD가 현재 프로젝트인지 확인
  local codex_cwd
  codex_cwd=$(tmux display-message -t "$codex_pane" -p '#{pane_current_path}' 2>/dev/null || true)
  if [ -n "$codex_cwd" ] && [ "$codex_cwd" != "$PWD" ]; then
    echo "WARN: Codex CWD($codex_cwd) ≠ 현재($PWD). cd 명령을 먼저 전송합니다."
    tmux send-keys -t "$codex_pane" "cd $PWD" Enter
    sleep 1
  fi

  # Codex가 프롬프트 대기 상태인지 확인
  local retries=0
  local max_retries=6
  while [ $retries -lt $max_retries ]; do
    local output
    output=$(tmux capture-pane -t "$codex_pane" -p -S -3 2>/dev/null || true)
    if echo "$output" | grep -qE "$prompt_pattern"; then
      break
    fi
    echo "Codex가 작업 중입니다. 5초 후 재시도... ($((retries+1))/$max_retries)"
    sleep 5
    retries=$((retries + 1))
  done

  if [ $retries -ge $max_retries ]; then
    release_lock
    echo "ERROR: Codex가 30초 내에 프롬프트로 돌아오지 않았습니다." >&2
    exit 1
  fi

  # 프롬프트 주입
  local rel_task_file=".handoff/queue/task-${task_id}.md"
  tmux send-keys -t "$codex_pane" \
    "${rel_task_file} 파일을 읽고 구현해줘. 끝나면 파일 안의 '완료 시 해야 할 것' 섹션을 반드시 실행해." \
    Enter

  echo "OK: task-${task_id} 를 Codex에 주입했습니다. (pane=$codex_pane)"
}

# ── poll ──────────────────────────────────────────
cmd_poll() {
  local task_id="$1"
  shift
  local timeout_override=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --timeout) timeout_override="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: config.json이 없습니다." >&2
    exit 1
  fi

  local codex_pane
  codex_pane=$(jq -r '.codex_pane' "$CONFIG_FILE")
  local poll_interval
  poll_interval=$(jq -r '.poll_interval_sec' "$CONFIG_FILE")
  local poll_timeout
  poll_timeout=${timeout_override:-$(jq -r '.poll_timeout_sec' "$CONFIG_FILE")}
  local prompt_pattern
  prompt_pattern=$(jq -r '.prompt_pattern' "$CONFIG_FILE")

  local elapsed=0

  echo "polling: task-${task_id} 완료 대기 중... (timeout=${poll_timeout}s)"

  while [ $elapsed -lt "$poll_timeout" ]; do
    # 1차: 시그널 파일 체크
    for f in "$HANDOFF_DIR/result/result-${task_id}".json "$HANDOFF_DIR/result/result-${task_id}"-r*.json; do
      if [ -f "$f" ]; then
        echo "DONE: 시그널 파일 감지 → $f"
        cat "$f"
        release_lock
        exit 0
      fi
    done

    sleep "$poll_interval"
    elapsed=$((elapsed + poll_interval))

    # 2차: tmux fallback
    local output
    output=$(tmux capture-pane -t "$codex_pane" -p -S -5 2>/dev/null || true)
    if echo "$output" | grep -qE "$prompt_pattern"; then
      echo "Codex가 프롬프트로 돌아왔지만 시그널 파일 없음. 15초 추가 대기..."
      sleep 15
      for f in "$HANDOFF_DIR/result/result-${task_id}".json "$HANDOFF_DIR/result/result-${task_id}"-r*.json; do
        if [ -f "$f" ]; then
          echo "DONE: 시그널 파일 감지 → $f"
          cat "$f"
          release_lock
          exit 0
        fi
      done
      echo "DONE_NO_SIGNAL: Codex 완료 (시그널 파일 미생성)"
      echo "--- capture-pane output ---"
      tmux capture-pane -t "$codex_pane" -p -S -30 2>/dev/null || true
      release_lock
      exit 0
    fi
  done

  echo "TIMEOUT: ${poll_timeout}초 경과. Codex가 아직 작업 중이거나 응답 없음."
  release_lock
  exit 1
}

# ── cancel ────────────────────────────────────────
cmd_cancel() {
  local task_id
  task_id=$(get_lock_task)
  if [ -n "$task_id" ]; then
    release_lock
    echo "OK: task-${task_id} 핸드오프 취소. lock 해제됨."
  else
    echo "진행 중인 핸드오프가 없습니다."
  fi
}

# ── status ────────────────────────────────────────
cmd_status() {
  local task_id
  task_id=$(get_lock_task)
  if [ -z "$task_id" ]; then
    echo "진행 중인 핸드오프가 없습니다."
    return 0
  fi

  echo "📋 Task: $task_id"
  echo "📄 Plan: $HANDOFF_DIR/queue/task-${task_id}.md"

  # result 존재 여부
  local has_result=false
  for f in "$HANDOFF_DIR/result/result-${task_id}"*.json; do
    if [ -f "$f" ]; then
      echo "✅ Result: $f"
      has_result=true
    fi
  done
  if [ "$has_result" = false ]; then
    echo "⏳ Status: 진행중 (시그널 파일 없음)"
  fi

  # Codex pane 상태
  if [ -f "$CONFIG_FILE" ]; then
    local codex_pane
    codex_pane=$(jq -r '.codex_pane' "$CONFIG_FILE")
    echo "🖥️ Codex pane ($codex_pane):"
    tmux capture-pane -t "$codex_pane" -p -S -3 2>/dev/null || echo "  (pane 접근 불가)"
  fi
}

# ── Main dispatch ─────────────────────────────────
case "${1:-}" in
  init)        shift; cmd_init "$@" ;;
  detect-pane) cmd_detect_pane ;;
  inject)      shift; cmd_inject "$@" ;;
  poll)        shift; cmd_poll "$@" ;;
  cancel)      cmd_cancel ;;
  status)      cmd_status ;;
  -h|--help)   usage ;;
  *)           usage; exit 1 ;;
esac
