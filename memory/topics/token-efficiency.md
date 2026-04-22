---
name: token-efficiency
description: "Claude Code/Codex 토큰 효율 관련 설정·환경변수 카탈로그. 적용 결정과 보류 사유를 추적하여 모델/버전 업그레이드 시 재평가 기반으로 사용."
type: reference
---

# Token Efficiency Catalog

Claude Code 토큰 소비를 줄이는 레버 카탈로그. **적용/보류 결정 + 사유**를 함께 기록하여
모델 업그레이드(예: 4.7 → 4.8) 시 재평가의 기반으로 쓴다.

출처: https://www.stdy.blog/increasing-token-efficiency-by-setting-adjustment-in-claude-and-codex/ (2026-04-19)
최종 확인 버전: Claude Code 2.1.114 / Codex 0.121.0

---

## 토큰이 새는 3가지 경로

1. 매 세션/매 턴 자동 주입되는 추가 텍스트 (git instructions, IDE 자동 컨텍스트 등)
2. 대화 히스토리에 남은 큰 툴 호출 출력 (대형 Bash/Read/MCP 응답)
3. 검색·커넥터·IDE 연동으로 인한 추가 호출 (web_search, ChatGPT apps 등)

---

## 적용 중 (settings.json)

| 설정 | 값 | 효과 | 적용일 |
|------|----|----|--------|
| `includeGitInstructions` | `false` | 매 세션 git workflow system prompt 블록 제거. CLAUDE.md §6이 대체 | 2026-04-21 |
| `attribution.commit` / `.pr` | `""` / `""` | Claude Code 자동 Co-Authored-By append 제거. 커밋 스킬이 HEREDOC으로 직접 부착 → 이중 attribution 방지 | 2026-04-21 |
| `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING` | `1` | adaptive thinking 비활성 (효과는 xhigh effort와 트레이드오프) | 이전 |
| `CLAUDE_CODE_DISABLE_AUTO_MEMORY` | `1` | 자동 메모리 로드 방지, 수동 관리(§1 4계층 메모리와 일관) | 이전 |
| `effortLevel` | `xhigh` | 장기 추론 품질 우선. 토큰 증가와 트레이드오프 | 이전 |

## 보류 (사유 포함)

| 설정 | 보류 사유 | 재평가 트리거 |
|------|---------|--------------|
| `BASH_MAX_OUTPUT_LENGTH=30000` | 실제 컨텍스트 폭주 사례 없음. 측정 후 결정 | Bash 출력으로 인한 컨텍스트 폭주 관측 시 |
| `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS=25000` | 꼬리 잘림 시 tail/grep 재호출로 역효과 가능 | 대형 파일 read가 실제 문제되는 세션 발생 시 |
| `MAX_MCP_OUTPUT_TOKENS=25000` | mysql/notion MCP 대형 응답을 쓰므로 리스크 | MCP 출력 때문에 토큰 폭주 관측 시 |
| `CLAUDE_CODE_GLOB_NO_IGNORE=false` | Spring Boot/Kotlin 백엔드에서 node_modules 노이즈 적음 | iOS/웹 프론트 비중이 커지면 재검토 |
| `ccb` worker alias | DISABLE_BUILTIN_AGENTS=1이 agent-council 등과 충돌 위험 | 비대화형 워커 패턴 실제 필요 시 |
| `DISABLE_TELEMETRY=1` | 토큰 절약 효과 없음 | 프라이버시 요구 시 |
| Codex 설정 (`web_search`, `tool_output_token_limit`, `--profile` 등) | Codex CLI 직접 사용 흐름 없음. `mcp__cli-proxy-api__ask_codex`는 다른 경로 | Codex CLI 워크플로우 도입 시 |

## 비대화형/워커 모드 env·flag (참고)

CLAUDE.md §1 컨텍스트 절약 원칙의 연장. 현재 미적용이지만 워커 패턴 도입 시 참조:

**환경변수**
- `ENABLE_CLAUDEAI_MCP_SERVERS=false` — MCP 서버 끄기
- `CLAUDE_CODE_DISABLE_CLAUDE_MDS=1` — 글로벌/프로젝트 CLAUDE.md 무시
- `CLAUDE_AGENT_SDK_DISABLE_BUILTIN_AGENTS=1` — 빌트인 서브에이전트·스킬 정의 제외
- `DISABLE_TELEMETRY=1` — Anthropic 아웃바운드 트래픽 차단

**플래그** (`claude` 뒤)
- `--tools "Bash,Edit,Glob,Grep,Read,Write"` — 네이티브 툴 선택 활성 (빈 문자열은 전부 비활성)
- `--strict-mcp-config` — CLI 명시 MCP만 사용, 전역 MCP 설정 무시
- `--disable-slash-commands` — `/help`, `/clear` 등 슬래시 커맨드 정의 제외
- `--no-session-persistence` — 세션 저장/재개 경로 비사용 (일회성)
- `--exclude-dynamic-system-prompt-sections` — 머신/환경 가변 섹션 제외 → 프롬프트 캐시 재사용률 상승
- `--system-prompt` — 시스템 프롬프트 완전 교체
- `CLAUDE_CODE_SIMPLE=1` 또는 `--bare` — 다 비움 (Oauth 로그인 미유지)

예시 alias (도입 시 참고):
```bash
alias ccb='ENABLE_CLAUDEAI_MCP_SERVERS=false CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 CLAUDE_CODE_DISABLE_CLAUDE_MDS=1 CLAUDE_AGENT_SDK_DISABLE_BUILTIN_AGENTS=1 DISABLE_TELEMETRY=1 claude --tools "Bash,Edit,Glob,Grep,Read,Write" --disable-slash-commands --exclude-dynamic-system-prompt-sections'
```

---

## 재평가 체크리스트

모델/버전 업그레이드 시 아래를 확인:
- [ ] 버전 번호 갱신 (Claude Code / Codex)
- [ ] 보류 항목의 "재평가 트리거" 조건 재확인
- [ ] 새로 추가된 env/flag 있는지 공식 문서 확인 (`https://code.claude.com/docs/en/settings.md`, `https://code.claude.com/docs/en/environment-variables.md` 등)
- [ ] 기존 설정 키가 deprecated/rename되었는지 확인

## 관련 참조

- 공식 문서 트릭: Anthropic/OpenAI 문서는 URL 뒤에 `.md`를 붙이면 마크다운 형식으로 받을 수 있음 (에이전트가 더 효율적으로 읽음)
- CLAUDE.md §1 컨텍스트 절약 원칙 (탐색/계획 상한, MCP 출력 최소화, Notion I/O 서브에이전트 위임, 에이전트 결과 크기 제한)
