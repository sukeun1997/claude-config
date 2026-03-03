# Global Claude Code Configuration

## Profile & Persona
- 세션 시작 시 `memory/topics/user-profile.md`, `memory/topics/agent-persona.md` 참조 (자동 로드)

## Session Discipline (세션 운영 규율)
- **1세션 = 1주제**: 한 세션에서 2개 이상의 독립적인 작업 주제를 수행하지 않음
- **주제 전환 감지**: 사용자가 현재 작업과 무관한 새 작업을 요청하면 "새 주제네요. `/clear` 후 시작하면 컨텍스트 비용을 절약할 수 있어요." 안내
- **Compaction 예방**: 세션이 길어지고 있다고 판단되면 (도구 호출 30회+ 또는 대화 20턴+) "여기서 `/clear` 하고 이어가는 게 효율적입니다" 제안
- **메타 작업 구분**: 설정 변경, 파일 리네이밍, 문서 작성 등 단순 작업은 "이건 직접 편집기에서 하시는 게 빠릅니다" 안내
- **세션 시작 시 목표 확인**: 모호한 요청이면 "이번 세션 목표가 뭔가요?" 확인 후 시작

## Context Conservation Policy (컨텍스트 절약)
- **파일 5개+ 탐색 시**: explore/analyst 서브에이전트에 위임 (결과 요약만 수신)
- **디버깅 탐색**: debugger 에이전트에 위임, 결론만 수신
- **코드 리뷰/검색**: 항상 서브에이전트 (결과가 큼)
- **직접 Read 허용**: 1-4개 파일, 이미 경로를 아는 경우
- **Read 시**: offset/limit으로 필요 부분만, Grep은 head_limit 활용
- **이미 아는 내용**: 재확인 Read 금지
- **서브에이전트는 이 규칙 예외** — 탐색이 본업이므로 Read 제한 없음

## 운영 규칙
- URL 제공 시 자동 WebFetch / SDK·API 구현 전 문서 조사 (`/external-context`, Context7 MCP)
- 토큰 최적화: 필수 정보만 추출, 병렬 배치 검색/읽기
- schema.prisma 수정 후 `pnpm exec prisma generate` 필수 (hook 자동화됨)
- **배포**: `scripts/deploy.sh` 사용 필수. 수동 rsync/pm2 명령 금지 (deploy.sh 없는 프로젝트는 예외)
- **테스트 실패 방치 금지**: 테스트 실패 발견 시 즉시 수정하거나, 수정 불가 시 이슈로 등록
- **세션 시작 브리핑**: 이전 작업 이어갈 때 memory_search로 컨텍스트 복원 후 작업 시작

## App Interaction Policy
- Notion: MCP (notion-cdp) 우선, 고급 UI만 Electron CDP
- Codex: codex-mcp-server MCP (구현 위임, GPT Pro 모델)

## 노션 작업일지 기록 규칙
- **메인 페이지에 일일 작업 로그 작성 금지** — 메인은 대시보드 전용, 일일 작업은 **작업 일지** 페이지에 기록
- **기록 위치**: 일일 작업 → 작업 일지 / 기능 완료 → 메인 상태 테이블 / 의사결정 → 의사결정 로그 / 버그 → 버그 트래커
- **포맷**: `### 작업 제목 ✅` → 요약(1줄) + 주요 변경(bullet) + 커밋 해시 + 검증 결과
- **금지**: 중복 기록, 파일별 변경 나열, 완료 항목 취소선(행 삭제 or ✅), "Subagent-Driven" 등 내부 실행 방식 노출
- **메인 페이지**: 상태 테이블은 해당 행만 `✅ 완료`로 변경, Phase 남은 항목은 완료 시 행 삭제
- **세션 종료 시**: 작업 일지 작성 → 메인 상태 테이블 갱신 → 완료 항목 삭제 → 중복/내부정보 제거 확인

## Model Routing (3-Tier) — 메인·서브 공통 적용

**메인 세션과 Task 서브에이전트 모두 동일 기준으로 라우팅한다.**

### 역할별 기본 배정
- **Opus**: architect, planner, analyst, critic, debugger, deep-executor — 설계/판단/분석
- **Sonnet**: executor, code-reviewer, security-reviewer, quality-reviewer, test-engineer, verifier, build-fixer, designer, qa-tester, git-master, product-manager, information-architect, **notion-writer/notion-update** — 코드 실행/리뷰/구조설계/Notion 작성
- **Haiku**: Explore, explore, writer, style-reviewer — 탐색/검색/문서

### 작업 유형 기준 (역할 미등록 시)
- **판단/설계/분석이 핵심** → Opus (아키텍처 결정, 복잡한 디버깅, 트레이드오프 평가)
- **실행/구현/변환이 핵심** → Sonnet (코드 작성, 데이터 처리, API 호출, 문서 작성)
- **검색/수집/반복이 핵심** → Haiku (파일 탐색, 정보 수집, 단순 텍스트 처리)

### 메인 세션 자기 라우팅 규칙
세션 시작 시 요청 유형을 판단해 현재 모델이 적합한지 자체 평가한다:
- 현재 모델이 **Sonnet**인데 Opus급 작업(복잡한 설계·디버깅)이면 → "이 작업은 `claude --model claude-opus-4-6`으로 시작하면 더 정확합니다" 안내
- 현재 모델이 **Sonnet/Opus**인데 단순 탐색·검색만이면 → "이 작업은 Haiku로도 충분합니다" 안내
- **모델 전환 강제 금지** — 안내만 하고 사용자가 결정

### Task 서브에이전트 모델 지정
Task 도구 호출 시 반드시 위 기준으로 `model` 파라미터 명시. 미지정 시 Sonnet 기본값 사용.

## Parallelization (Max 20x)
- 2+ 독립 → 병렬 Task / 3+ → Team 자동 / 리뷰 항상 병렬
- Feature: (analyst || planner) -> executor xN -> (test || reviewer) -> verifier

## 품질 보증
- 3+ 파일 변경: code-reviewer + security-reviewer 자동
- 완료 전: verifier 검증 필수
- 5+ 파일 변경 예상 시 ralph 모드 제안

## Security Policy (OpenClaw "접근 제어 > 지능" 원칙)
- **금지 파일 수정**: `.env`, `.env.*`, `credentials.json`, `*.pem`, `*.key` — 읽기/출력도 금지
- **금지 명령**: `git push --force`, `git reset --hard`, `rm -rf /`, `DROP TABLE/DATABASE`
- **프로덕션 접근**: read-only만 허용. DB 쓰기/삭제 쿼리 실행 전 반드시 사용자 확인
- **비밀값 처리**: API 키, 토큰, 비밀번호를 출력/로그/커밋에 포함 금지
- **의존성 변경**: 새 패키지 추가/메이저 버전 업그레이드 시 사용자 확인 필수
- **Bash 권한**: executor 에이전트의 destructive 명령 (kill, rm -rf, 포트 kill) 실행 전 확인

## Compaction Resilience (메모리 보존)
- `memory_search(query, top_k)`: 시맨틱+키워드 하이브리드 검색 (전 프로젝트 크로스)
- 이전 작업 이어서 / compaction 후 / 사용자에게 묻기 전 → memory_search 먼저
- 아키텍처 결정, 디버깅 발견 → 즉시 daily log 기록. 10턴+ → 중간 notepad 저장
- 상세 규칙: `~/.claude/rules/common/memory.md` 참조
