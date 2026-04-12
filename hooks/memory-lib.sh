#!/usr/bin/env bash
# memory-lib.sh — Shared utilities for memory persistence hooks
# Source this file from other hook scripts: source "$HOME/.claude/hooks/memory-lib.sh"

set -euo pipefail

# Global memory directory
get_memory_dir() {
  echo "$HOME/.claude/memory"
}

# Detect project name from CWD
# Maps known project paths to short names; unknown → "global"
detect_project() {
  local cwd="${PWD:-$(pwd)}"
  # .claude-project 파일이 있으면 그 내용을 프로젝트명으로 사용
  local check_dir="$cwd"
  while [ "$check_dir" != "/" ]; do
    if [ -f "$check_dir/.claude-project" ]; then
      head -1 "$check_dir/.claude-project" | tr -d '[:space:]'
      return
    fi
    check_dir=$(dirname "$check_dir")
  done
  # 폴백: 경로 기반 매핑
  case "$cwd" in
    */maple*|*391*) echo "maple" ;;
    */todo-app*) echo "haru" ;;
    */building-mang*) echo "building" ;;
    */lendit*) echo "lendit" ;;
    */ktx_reservation*) echo "ktx" ;;
    */my-game*) echo "game" ;;
    */news*) echo "news" ;;
    */관리*) echo "cdp" ;;
    */.claude|*/.claude/*) echo "global" ;;
    *) echo "global" ;;
  esac
}

# Get daily log filename for today (project-aware)
# Returns: YYYY-MM-DD.md (global) or YYYY-MM-DD-{project}.md (project)
daily_log_filename() {
  local date_str="$1"
  local project
  project=$(detect_project)
  if [ "$project" = "global" ]; then
    echo "${date_str}.md"
  else
    echo "${date_str}-${project}.md"
  fi
}

# Date utilities (macOS compatible)
today() {
  date +%Y-%m-%d
}

yesterday() {
  # macOS uses -v flag, Linux uses -d flag
  date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d
}

now_time() {
  date +%H:%M
}

year_month() {
  date +%Y-%m
}

# Sanitize branch name to filesystem-safe slug
branch_slug() {
  echo "$1" | sed 's|/|--|g' | sed 's|[^a-zA-Z0-9._-]||g'
}

# Ensure all memory subdirectories exist
ensure_dirs() {
  local mem_dir="$1"
  mkdir -p "$mem_dir/daily" "$mem_dir/topics" "$mem_dir/archive" "$mem_dir/sessions" "$mem_dir/active"
}

# Get active context filename for current project
active_context_filename() {
  local project
  project=$(detect_project)
  if [ "$project" = "global" ]; then
    echo "global-context.md"
  else
    echo "${project}-context.md"
  fi
}

# Check if a file was modified within the last N hours (default: 24)
is_context_fresh() {
  local file="$1"
  local max_age_hours="${2:-24}"
  if [ ! -f "$file" ]; then return 1; fi
  local now file_mod age_hours
  now=$(date +%s)
  file_mod=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo 0)
  age_hours=$(( (now - file_mod) / 3600 ))
  [ "$age_hours" -lt "$max_age_hours" ]
}

# Safe file read — returns empty string if file doesn't exist
safe_read() {
  if [ -f "$1" ]; then
    cat "$1"
  else
    echo ""
  fi
}

# Count lines in a file (0 if not exists)
line_count() {
  if [ -f "$1" ]; then
    wc -l < "$1" | tr -d ' '
  else
    echo "0"
  fi
}

# Load GEMINI_API_KEY from .zshrc if not already in environment
# Hook scripts run as non-login bash, so .zshrc exports are not inherited
load_gemini_key() {
  if [ -z "${GEMINI_API_KEY:-}" ] && [ -f "$HOME/.zshrc" ]; then
    GEMINI_API_KEY=$(grep -m1 '^export GEMINI_API_KEY=' "$HOME/.zshrc" | sed 's/^export GEMINI_API_KEY="//' | sed 's/"$//')
    export GEMINI_API_KEY
  fi
}

# Extract key sections from active context file (20-line budget)
# Preserves Why/Goal + Progress summary + Next + Handoff/Key Decisions
# Unlike head/tail, this captures both top and bottom sections
safe_read_context() {
  local file="$1"
  if [ ! -f "$file" ] || [ ! -s "$file" ]; then echo ""; return; fi

  local output=""
  # Title line
  local title
  title=$(head -1 "$file")
  output+="${title}
"

  # Extract sections with per-section line limits
  local section_found=false
  for section_spec in "Why:3" "Goal:3" "Progress:3" "Status:3" "Next:5" "Key Decisions:3" "Handoff:5" "Open Questions:2"; do
    local section="${section_spec%%:*}"
    local limit="${section_spec##*:}"
    local content
    content=$(sed -n "/^## ${section}$/,/^## /{/^## ${section}$/d;/^## /d;p;}" "$file" | sed '/^$/d' | head -"$limit")
    if [ -n "$content" ]; then
      output+="## ${section}
${content}
"
      section_found=true
    fi
  done

  if [ "$section_found" = true ]; then
    echo "$output"
  else
    # Fallback: no recognized sections, use head
    head -20 "$file"
  fi
}

# Read file with line limit (tail: keep most recent entries)
# Daily logs append chronologically, so tail gives the latest context
safe_read_limited() {
  local file="$1"
  local max_lines="${2:-100}"
  if [ -f "$file" ]; then
    local total
    total=$(wc -l < "$file" | tr -d ' ')
    if [ "$total" -gt "$max_lines" ]; then
      echo "(... truncated: showing last ${max_lines} of ${total} lines ...)"
      tail -n "$max_lines" "$file"
    else
      cat "$file"
    fi
  else
    echo ""
  fi
}

# Find Claude Code project JSONL directory for current CWD
# Claude Code encodes CWD path: / → -, non-ASCII → - (sometimes)
# Returns: directory path or empty string
find_project_jsonl_dir() {
  local projects_base="$HOME/.claude/projects"
  [ -d "$projects_base" ] || return

  local cwd="${PWD:-$(pwd)}"

  # Strategy 1: Exact path encoding (/ → -)
  local encoded=$(echo "$cwd" | sed 's|/|-|g')
  if [ -d "$projects_base/$encoded" ] && ls "$projects_base/$encoded"/*.jsonl >/dev/null 2>&1; then
    echo "$projects_base/$encoded"
    return
  fi

  # Strategy 2: Try with non-ASCII chars replaced by -
  local ascii_encoded=$(echo "$cwd" | sed 's|/|-|g' | LC_ALL=C sed 's/[^[:print:]-]/-/g')
  ascii_encoded=$(echo "$ascii_encoded" | sed 's/--*/-/g')
  if [ -d "$projects_base/$ascii_encoded" ] && ls "$projects_base/$ascii_encoded"/*.jsonl >/dev/null 2>&1; then
    echo "$projects_base/$ascii_encoded"
    return
  fi

  # Strategy 3: Search for directory containing CWD basename
  local basename_part=$(basename "$cwd")
  local found=""
  # Use ASCII-safe first 5 chars for matching
  local match_hint=$(echo "$basename_part" | LC_ALL=C sed 's/[^[:alnum:]]//g' | head -c 5)
  if [ -n "$match_hint" ]; then
    for dir in "$projects_base"/*/; do
      [ -d "$dir" ] || continue
      local dirname=$(basename "$dir")
      if echo "$dirname" | LC_ALL=C grep -q "$match_hint" 2>/dev/null; then
        if ls "$dir"*.jsonl >/dev/null 2>&1; then
          found="${dir%/}"
          break
        fi
      fi
    done
  fi

  # Strategy 4: Match on parent directory name portion
  if [ -z "$found" ]; then
    local parent_part=$(basename "$(dirname "$cwd")")
    local parent_hint=$(echo "$parent_part" | LC_ALL=C sed 's/[^[:alnum:]]//g' | head -c 8)
    if [ -n "$parent_hint" ]; then
      for dir in "$projects_base"/*/; do
        [ -d "$dir" ] || continue
        local dirname=$(basename "$dir")
        if echo "$dirname" | LC_ALL=C grep -q "$parent_hint" 2>/dev/null && ls "$dir"*.jsonl >/dev/null 2>&1; then
          found="${dir%/}"
          break
        fi
      done
    fi
  fi

  [ -n "$found" ] && echo "$found"
}
