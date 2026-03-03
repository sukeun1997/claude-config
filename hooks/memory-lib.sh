#!/usr/bin/env bash
# memory-lib.sh — Shared utilities for memory persistence hooks
# Source this file from other hook scripts: source "$HOME/.claude/hooks/memory-lib.sh"

set -euo pipefail

# Global memory directory (프로젝트 무관, 글로벌 daily log)
get_memory_dir() {
  echo "$HOME/.claude/memory"
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

# Ensure all memory subdirectories exist
ensure_dirs() {
  local mem_dir="$1"
  mkdir -p "$mem_dir/daily" "$mem_dir/topics" "$mem_dir/archive"
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
