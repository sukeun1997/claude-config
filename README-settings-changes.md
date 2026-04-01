# settings.json 변경 필요 사항

`~/.claude/settings.json`의 `hooks.PostToolUse` 배열에 아래 항목을 추가하세요.

## 추가할 훅 설정

```json
{
  "matcher": "Agent",
  "hooks": [
    {
      "type": "command",
      "command": "\"$HOME/.claude/hooks/agent-usage-tracker.sh\"",
      "timeout": 2
    }
  ]
}
```

## 추가 위치

`hooks.PostToolUse` 배열의 마지막 항목 뒤에 추가합니다.

기존 예시:
```json
{
  "hooks": {
    "PostToolUse": [
      { "matcher": "Edit|Write", ... },
      { "matcher": "Skill", ... },
      // ← 여기에 위 항목 추가
    ]
  }
}
```

## 훅 파일 배치

`agent-usage-tracker.sh`를 `~/.claude/hooks/`에 복사하세요:

```bash
cp /tmp/harness-diet/hooks/agent-usage-tracker.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/agent-usage-tracker.sh
```

## 기록 위치

Agent 호출마다 아래 경로에 월별 JSONL로 기록됩니다:

```
~/.claude/memory/metrics/agent-usage-YYYY-MM.jsonl
```

### 레코드 포맷

```json
{"date":"2026-04-01","time":"14:30","agent":"executor","model":"claude-sonnet-4-5","description":"Fix the login bug in AuthService..."}
```

- `agent`: `subagent_type` 값 (없으면 `general-purpose`)
- `model`: 지정된 모델명 (없으면 빈 문자열)
- `description`: `prompt` 앞 80자 요약
