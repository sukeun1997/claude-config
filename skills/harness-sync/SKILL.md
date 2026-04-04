---
name: harness-sync
description: "회사↔집 하네스 데이터 동기화. claude-config 레포를 경유하여 메트릭/observations/instincts/failure-log를 머지. Use when user says '/harness-sync', '동기화', 'sync', '회사 데이터 합치기', '집 데이터 가져오기'."
---

# Harness Sync — 회사↔집 데이터 동기화

claude-config 레포(`sukeun1997/claude-config`)의 `sync-data/` 디렉토리를 경유하여
L5 자기 진화에 필요한 데이터를 머신 간 동기화한다.

## When to Apply

- `/harness-sync push` — 현재 머신의 데이터를 레포에 업로드
- `/harness-sync pull` — 레포에서 데이터를 가져와 로컬에 머지
- `/harness-sync status` — 동기화 상태 확인
- 인자 없으면 `status` 표시 후 push/pull 선택 질문

## 동기화 대상

| 데이터 | 로컬 경로 | sync-data/ 경로 | 머지 방식 |
|--------|-----------|-----------------|-----------|
| 세션 메트릭 | `memory/metrics/sessions.jsonl` | `metrics/sessions.jsonl` | JSONL dedup append |
| Agent 사용 | `memory/metrics/agent-usage-*.jsonl` | `metrics/agent-usage-*.jsonl` | JSONL dedup append |
| Observations | `homunculus/observations.jsonl` | `homunculus/observations.jsonl` | JSONL dedup append |
| Instincts | `homunculus/instincts/personal/*.md` | `instincts/*.md` | newer mtime wins |
| Failure log | `memory/topics/failure-log.md` | `failure-log.md` | 행 수 많은 쪽 우선 |
| Skill usage | `memory/skill-usage/*.jsonl` | `skill-usage/*.jsonl` | JSONL dedup append |

## 실행 절차

### Push

1. `~/.claude/` 에서 `git stash` (작업 중 변경 보호)
2. `sync-data/` 디렉토리에 위 데이터 파일 복사
3. `sync-data/manifest.json` 작성 (hostname, timestamp, 파일 목록)
4. `git add sync-data/ && git commit -m "chore: sync harness data [hostname]" && git push`
5. `git stash pop` (있었으면)

```bash
# 핵심 명령
CLAUDE_DIR="$HOME/.claude"
SYNC_DIR="$CLAUDE_DIR/sync-data"
mkdir -p "$SYNC_DIR/metrics" "$SYNC_DIR/homunculus" "$SYNC_DIR/instincts" "$SYNC_DIR/skill-usage"

# Metrics
cp "$CLAUDE_DIR/memory/metrics/sessions.jsonl" "$SYNC_DIR/metrics/" 2>/dev/null || true
cp "$CLAUDE_DIR/memory/metrics"/agent-usage-*.jsonl "$SYNC_DIR/metrics/" 2>/dev/null || true

# Observations + Instincts (gitignored locally, but tracked in sync-data/)
cp "$CLAUDE_DIR/homunculus/observations.jsonl" "$SYNC_DIR/homunculus/" 2>/dev/null || true
cp "$CLAUDE_DIR/homunculus/instincts/personal"/*.md "$SYNC_DIR/instincts/" 2>/dev/null || true

# Failure log
cp "$CLAUDE_DIR/memory/topics/failure-log.md" "$SYNC_DIR/" 2>/dev/null || true

# Skill usage
if [ -d "$CLAUDE_DIR/memory/skill-usage" ]; then
  cp "$CLAUDE_DIR/memory/skill-usage"/*.jsonl "$SYNC_DIR/skill-usage/" 2>/dev/null || true
fi

# Manifest
python3 -c "
import json, datetime, socket, os
manifest = {
    'hostname': socket.gethostname(),
    'timestamp': datetime.datetime.now().isoformat(),
    'files': []
}
for root, dirs, files in os.walk('$SYNC_DIR'):
    for f in files:
        if f != 'manifest.json':
            manifest['files'].append(os.path.relpath(os.path.join(root, f), '$SYNC_DIR'))
print(json.dumps(manifest, indent=2, ensure_ascii=False))
" > "$SYNC_DIR/manifest.json"

# Commit + Push
cd "$CLAUDE_DIR"
git add sync-data/
git commit -m "chore: sync harness data [$(hostname -s)] $(date +%Y-%m-%d)"
git push origin main
```

### Pull

1. `cd ~/.claude && git pull origin main`
2. `sync-data/` 에서 각 파일을 로컬 경로로 머지
3. JSONL 파일: 중복 제거 append (`sort -u` 또는 Python dedup)
4. Instinct 파일: 로컬에 없으면 복사, 있으면 mtime 비교
5. Failure log: wc -l 비교 후 행 수 많은 쪽 채택

```bash
CLAUDE_DIR="$HOME/.claude"
SYNC_DIR="$CLAUDE_DIR/sync-data"

cd "$CLAUDE_DIR" && git pull origin main

# JSONL dedup merge 함수
merge_jsonl() {
  local remote="$1" local_f="$2"
  [ -f "$remote" ] || return
  mkdir -p "$(dirname "$local_f")"
  touch "$local_f"
  # 기존 + 리모트 합치고 중복 제거
  cat "$local_f" "$remote" | sort -u > "${local_f}.tmp"
  mv "${local_f}.tmp" "$local_f"
}

# Metrics
merge_jsonl "$SYNC_DIR/metrics/sessions.jsonl" "$CLAUDE_DIR/memory/metrics/sessions.jsonl"
for f in "$SYNC_DIR/metrics"/agent-usage-*.jsonl; do
  [ -f "$f" ] && merge_jsonl "$f" "$CLAUDE_DIR/memory/metrics/$(basename "$f")"
done

# Observations
merge_jsonl "$SYNC_DIR/homunculus/observations.jsonl" "$CLAUDE_DIR/homunculus/observations.jsonl"

# Instincts
mkdir -p "$CLAUDE_DIR/homunculus/instincts/personal"
for f in "$SYNC_DIR/instincts"/*.md; do
  [ -f "$f" ] || continue
  LOCAL_F="$CLAUDE_DIR/homunculus/instincts/personal/$(basename "$f")"
  if [ ! -f "$LOCAL_F" ] || [ "$f" -nt "$LOCAL_F" ]; then
    cp "$f" "$LOCAL_F"
  fi
done

# Failure log (행 수 많은 쪽)
if [ -f "$SYNC_DIR/failure-log.md" ]; then
  REMOTE_LINES=$(wc -l < "$SYNC_DIR/failure-log.md" | tr -d ' ')
  LOCAL_LINES=$(wc -l < "$CLAUDE_DIR/memory/topics/failure-log.md" 2>/dev/null | tr -d ' ' || echo 0)
  if [ "$REMOTE_LINES" -gt "$LOCAL_LINES" ]; then
    cp "$SYNC_DIR/failure-log.md" "$CLAUDE_DIR/memory/topics/failure-log.md"
  fi
fi

# Skill usage
if [ -d "$SYNC_DIR/skill-usage" ]; then
  for f in "$SYNC_DIR/skill-usage"/*.jsonl; do
    [ -f "$f" ] && merge_jsonl "$f" "$CLAUDE_DIR/memory/skill-usage/$(basename "$f")"
  done
fi
```

### Status

manifest.json을 읽어서 마지막 동기화 시간, 호스트, 파일 목록을 표시.
로컬 데이터와 sync-data/의 차이를 비교하여 "push 필요" / "pull 필요" / "동기화됨" 판정.

## 주의사항

- push 전에 반드시 main 브랜치인지 확인
- JSONL 머지 시 `sort -u`는 JSON 키 순서가 다르면 중복 제거 실패할 수 있음 — 동일 스크립트가 생성한 데이터이므로 키 순서 일관됨
- conflict 발생 시 sync-data/ 파일은 항상 theirs 채택 (데이터 손실보다 중복이 나음)
