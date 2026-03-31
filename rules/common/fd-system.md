# Feature Design (FD) System

설계 결정을 마크다운 파일로 영속화하여 과거 결정이 축적되고, 새 에이전트의 계획 품질이 향상되는 시스템.

## FD 라이프사이클
```
Planned → Design → Open → In Progress → Pending Verification → Complete
                                                              → Deferred / Closed
```

## FD 슬래시 명령어
| 명령어 | 기능 |
|--------|------|
| `/fd-new` | 아이디어에서 새 FD 파일 생성, 인덱스에 등록 |
| `/fd-status` | 전체 FD 상태 대시보드 |
| `/fd-explore` | 세션 부트스트랩: 프로젝트 컨텍스트 + 활성 FD 로드 |
| `/fd-deep` | 4개 Opus 에이전트 병렬 다관점 설계 탐색 |
| `/fd-verify` | 구현 검수 + 검증 계획 실행 |
| `/fd-close` | FD 아카이빙, 인덱스/변경로그 업데이트 |

## FD 규칙
- **FD 파일 위치**: `docs/features/FD-{NNN}.md` (프로젝트별)
- **인덱스**: `docs/features/FEATURE_INDEX.md`
- **아카이브**: `docs/features/archive/`
- **커밋 prefix**: `FD-{NNN}: {description}`
- **인라인 피드백**: `%% 코멘트` 형태로 FD 파일에 직접 기록
- Plan-First(§1)와 통합: EnterPlanMode 결과를 FD 파일로 영속화
