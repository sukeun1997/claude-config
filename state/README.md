# `~/.claude/state/`

Claude 하네스 런타임 상태 파일 저장소.

## 규약

- 모든 JSON 파일은 `schemaVersion` 필드 필수 (현재 v1)
- 표준 envelope:
  ```json
  {
    "schemaVersion": 1,
    "kind": "<state-kind>",
    "updatedAt": "<ISO-8601>",
    "data": { /* 실제 페이로드 */ }
  }
  ```

## 위치 정책

이 디렉토리에 두는 것:
- 하네스 자체가 생성/소비하는 휘발성·캐시·정책 파일

이 디렉토리에 두지 않는 것:
- Claude Code 공식 위치 파일 — `.mcp.json`, `settings.json`, `keybindings.json`
- 외부 도구 소유 — `.omc-config.json`, `.omc-version.json`
- Claude Code CLI가 hardcoded path로 직접 갱신 — `.last-cleanup` (루트 유지, 옮겨도 즉시 재생성됨)
- hooks가 hardcoded path로 참조하는 파일 — `.session-stats.json` (별도 마이그레이션 필요)

## 현재 보유 파일

| 파일 | kind | 출처 | 비고 |
|------|------|------|------|
| `mcp-needs-auth-cache.json` | `mcp-auth-cache` | MCP 서버 인증 필요 캐시 | 이전 위치: `~/.claude/mcp-needs-auth-cache.json` |
| `policy-limits.json` | `policy-limits` | 사용 정책 제한값 | 이전 위치: `~/.claude/policy-limits.json` |

## 새 상태 파일 추가 시

1. envelope 형식 따르기
2. 본 README 표에 행 추가
3. hardcoded 참조하는 hook이 있으면 함께 갱신
