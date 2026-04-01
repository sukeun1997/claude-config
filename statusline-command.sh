#!/bin/bash
# Claude Code statusLine command
# Mirrors Powerlevel10k lean style: dir + git | model + context% + time

input=$(cat)

# --- Extract fields from JSON ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# --- Shorten directory (replace $HOME with ~) ---
short_dir="${cwd/#$HOME/~}"

# --- Git info (skip lock to avoid blocking) ---
git_branch=""
git_dirty=""
if git_ref=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null); then
  git_branch="$git_ref"
  if [ -n "$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" status --porcelain 2>/dev/null)" ]; then
    git_dirty="*"
  fi
fi

# --- Context bar ---
ctx_info=""
if [ -n "$used_pct" ]; then
  used_int=${used_pct%.*}
  if [ "$used_int" -ge 80 ]; then
    ctx_color="\033[0;31m"   # red
  elif [ "$used_int" -ge 50 ]; then
    ctx_color="\033[0;33m"   # yellow
  else
    ctx_color="\033[0;32m"   # green
  fi
  ctx_info=" ${ctx_color}ctx:${used_pct}%\033[0m"
fi

# --- Time ---
now=$(date +%H:%M)

# --- Left: dir + git ---
left="\033[0;34m${short_dir}\033[0m"
if [ -n "$git_branch" ]; then
  left="${left} \033[0;35m${git_branch}${git_dirty}\033[0m"
fi

# --- Right: model + context + time ---
right=""
if [ -n "$model" ]; then
  right="\033[0;36m${model}\033[0m"
fi
right="${right}${ctx_info} \033[0;37m${now}\033[0m"

echo -e "${left}  ${right}"
