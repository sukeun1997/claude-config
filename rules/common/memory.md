# Memory Persistence System

4계층 메모리 + 브랜치별 Active Context로 compaction 이후에도 핵심 컨텍스트를 보존한다.
**원칙: "파일이 진실의 원천 — 모델은 디스크에 쓴 것만 기억한다"**

## 4-Layer Architecture (branch-based Active Context 통합)

| Layer | 파일 | 로딩 방식 | 용도 | 수명 |
|-------|------|-----------|------|------|
| **Active** | `memory/active/{branch-slug}.md` | SessionStart 자동 주입 (브랜치별) | 현재 작업 상태 (20줄 이하) | 브랜치 머지/삭제 시 archive 이동 |
| **Hot** | `memory/daily/YYYY-MM-DD.md` | SessionStart 자동 주입 (오늘 마지막 20줄) | 당일 작업 로그 | 14일 후 archive/{YYYY-MM}/ 이동 |
| **Always** | `memory/MEMORY.md` | 시스템 프롬프트 상시 로드 | 핵심 장기 기억 (150줄 소프트 리밋) | 영구 (수동 관리) |
| **Cold** | `memory/topics/*.md` | 온디맨드 (필요시 Read) | 도메인별 상세 지식 | 영구 |

## Active Context (브랜치별 작업 맥락)

- `memory-active-context.sh init`: feature 브랜치 진입 시 skeleton 자동 생성
- `memory-active-context.sh update`: Stop 훅에서 자동 갱신
- main/master/develop 브랜치는 건너뜀
- 구조: Why / Progress / Next / Open Questions
- 머지/삭제된 브랜치의 active context는 SessionEnd에서 archive/ 이동

## Daily Log 작성 시점

아래 이벤트 발생 시 **즉시** `memory/daily/YYYY-MM-DD.md`에 기록:
- 버그 발견 및 해결 (root cause + fix)
- 아키텍처/설계 결정 및 근거
- 새로운 패턴, 컨벤션, 모범 사례 발견
- 중요 설정 변경 (build, infra, CI/CD)
- 디버깅 과정에서 발견한 핵심 인사이트
- 작업 진행 상태 (진행 중인 태스크의 중간 상태)

### Daily Log 포맷
```markdown
### HH:MM - [Topic]
- bullet point summaries
- [PROMOTE] 장기 보존이 필요한 항목에 태그
```

## MEMORY.md 관리

- **150줄 소프트 리밋** — 초과 시 SessionStart에서 경고
- 새 항목 추가 전, 오래된/불필요한 항목 제거
- 상세 내용은 `memory/topics/*.md`로 이동하고 MEMORY.md에는 링크만 유지
- `[PROMOTE]` 태그된 Daily Log 항목을 정기적으로 MEMORY.md에 승격

## Topic 파일 관리

- **생성 기준**: 동일 주제에 대한 항목이 Daily Log에서 10개 이상 누적
- **네이밍**: `memory/topics/{domain-name}.md` (예: `kafka-glue.md`, `spring-security.md`)
- **MEMORY.md에 인덱스**: `- 상세: [topics/kafka-glue.md](topics/kafka-glue.md)` 형태로 링크

## [PROMOTE] 승격 프로세스

1. Daily Log에서 `[PROMOTE]` 태그 항목 확인
2. MEMORY.md에 요약 추가 (1-2줄)
3. 상세 내용은 해당 Topic 파일로
4. Daily Log의 `[PROMOTE]` 태그를 `[PROMOTED]`로 변경

## 메모리 검색

필요한 정보를 찾을 때:
1. MEMORY.md 확인 (이미 시스템 프롬프트에 로드됨)
2. 오늘/어제 Daily Log 확인 (SessionStart에서 주입됨)
3. **Hybrid search**: `python3 ~/.claude/hooks/memory-search.py search "query"` (기본: BM25+Vector RRF 융합)
   - `--mode bm25`: 정확 키워드 매칭, `--mode vector`: 의미 검색, `--compact`: 간결 출력
4. `Grep` 도구로 `memory/` 디렉토리 전체 검색 (정확 텍스트 매칭)
5. Topic 파일에서 상세 정보 조회

## 자동화 (Hooks)

- **SessionStart**: 오늘+어제 Daily Log 자동 주입
- **PreCompact**: compaction 전 중요 컨텍스트 Daily Log 플러시
- **Stop**: 의미 있는 작업이었으면 세션 요약 저장 유도
- **SessionEnd**: 14일 초과 Daily Log → archive/ 이동
