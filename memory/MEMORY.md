# Core Memory

## 사용자 프로필
- 상세: [topics/user-profile.md](topics/user-profile.md)

## 작업 환경
- macOS, zsh, Claude Code CLI 사용
- GitHub: sukeun1997 (gh CLI 인증됨)
- Notion: MCP (`plugin:Notion:notion`, 도구 프리픽스 `mcp__plugin_Notion_notion__*`) 연동
- Memory: 4계층 (Active: active/+sessions/, Hot: daily/, Always: MEMORY.md, Cold: topics/)

## 글로벌 설정 구조 (~/.claude/)
- `CLAUDE.md`: 글로벌 에이전트 운영 매뉴얼 (2026-07-19 슬림 리팩토링 — 중복/구형 모델용 규칙 제거, 하네스 설계 문서는 `docs/harness/`로 이동)
- `hooks/`: 활성 21개 (2026-07-12 기준, 정확 목록은 `ls hooks/`) — 메모리 계열, 가드 계열(agent-model-guard, read-edit-gate, governance-guard, settings-integrity-guard), 관측 계열, 기타. 은퇴 훅은 `hooks/deprecated/`
- `scripts/`: failure-log-classify, sync-settings, deploy 등
- `memory-search MCP`: ~/IdeaProjects/관리/memory-mcp-server (BM25+Vector 하이브리드)

## 원격 레포 동기화
- 글로벌 설정 레포: `sukeun1997/claude-config` (GitHub, public)
- 로컬 ~/.claude: git 초기화됨

## 주요 결정 이력 (topics/ 인덱스)
- [결정 이력](topics/absorbed-articles.md) — absorb 적용 기록
- [삽질 패턴](topics/failure-log.md) — 원인 분류 + 해법
- [평가 교정](topics/evaluation-calibration-pattern.md) — 리뷰어 평가 기준
- [L5 로드맵](topics/l5-roadmap.md) — 4.5→5.0 단계별 액션
- [Promoted 인사이트 아카이브](topics/promoted-insights-archive.md) — 프로젝트별 상세 (CSS/Prisma/배포/Grafana/FEP/JB_SEND/banking 등, 온디맨드)
- [haru 프로젝트 이력](topics/haru-project-history.md)
- [토큰 효율](topics/token-efficiency.md)
- [학습 계획 2026-05](topics/learning-plan-2026-05.md)

## Promoted 인사이트 (메타/프로세스 — Always)
> 프로젝트별 상세는 아카이브로 이동. 여기엔 하네스/프로세스 교훈 + 활성 운영 사실만 유지.

- **(04-06)** settings base+local 분리 시 hooks 보호: frozen-keys + integrity guard
- **(04-10)** 하네스 4.5 유지. 5.0 갭: evolved skill 미발동 + friction 은퇴 0건 / absorb 주 2회(화·금) 배치 / Active Context Hygiene 자동 경고
- **(04-14)** executor 안전 게이트 위반 패턴: "BLOCKED 보고" 지시해도 진행 경로 있으면 우회. 운영 DB 등 critical 경로는 명시 차단 명령 또는 메인 세션 사전 .env 확인 후 위임
- **(04-18)** failure-log 적체 게이트 = 주간 리뷰 첫 관문 (15건+면 KPI 분석 무의미). 분류는 Harness/Context/Prompt 3계층 / W16 1위 원인 = 파일 Read 선행 미흡
- **(04-21)** 스킬 설계: 메인 SKILL.md 얇게(200줄 미만) + 상세는 references/ lazy-load (Anthropic 공식 패턴)
- **(04-24)** 2단 critic(내부+독립+적용가치 재검증)이 단계별로 다른 false positive를 거름. "버그인지"와 "적용 가치"는 다른 축 / 리뷰어는 라인번호+근거 필수 + critic Read 검증 필요
- **(04-26)** TestFlight 새 빌드 실패 최빈 원인 = CFBundleVersion 동일 / 클라 에러 LGTM 수집 = SLF4J logger.warn 한 줄 → docker stdout → Alloy
- **(05-16)** deprecated 정리 PR은 fallback dry-run 검증 후 머지 / "성숙도" 척도(8축 vs L1-L5) 명시
- **(05-19)** 새 라우트 안 잡힐 때: ① grep 라우트 존재 → ② lsof PID+uptime → ③ stale이면 재시작 (tsx watch stale 주의)
- **(05-23)** Read-before-Edit를 PreToolUse 차단 훅으로 승격 — friction 룰의 코드 enforcement 전환 첫 사례
- **(05-25)** friction 룰 N회 방지실패 → (a)강도상향 (b)훅 자동화 (c)은퇴 중 택1 (read-edit-gate가 (b) 첫 사례)
- **(06-23)** 대형 PR 분할: "diff 크다" 호소 시 prod/test 라인 분포부터. 테스트가 주범이면 관심사별 stacked PR로 테스트까지 분리. checkout-by-file + 단계별 컴파일 + 최종 트리동일성 검증
- **(06-24)** stacked PR rebase 함정: base amend 후 plain rebase 금지 — `git rebase --onto <new-base> <old-base-sha>`로 old-base 이후만 재생, force-with-lease 순차 갱신
- **(06-25)** stacked PR develop 재정착: 순차 rebase --onto 재구성 + 최종 트리를 기검증 브랜치와 diff — 동일하면 재검증 불필요
- **(07-11)** JPA N+1/DB 인덱스/Redis 캐시/iOS @Observable은 이미 최적화 완료 — 재분석 불필요
- **(07-11)** worktree 병렬 패턴: main 수정 + 테스트 작성 동시 진행 시 "public 시그니처 유지 계약 + 테스트 레인 worktree 격리 + 완료 후 통합 재검증"
- **(07-12)** .mcp.json 시크릿은 항상 `${ENV_VAR}` 참조만 (~/.zshrc export). GEMINI_API_KEY 평문 노출 이관 완료
- **(07-12)** review-week 수동 트리거 의존이 구조적 약점 — 리마인더 자동화 필요
- **(07-12)** macOS `find /tmp -maxdepth 1` 무동작 — /tmp symlink, trailing slash 필수
- **(07-12)** Codex 위임 가시성: codex-bridge(tmux) 대신 orca CLI (terminal create → task-create → dispatch --inject → terminal read로 RESULT_JSON 확인)
- **(07-13)** 침묵 허용(`|| true`)과 실패 관측은 항상 세트. "설치했다 ≠ 작동한다" — 기전 설치 후 가짜 입력 발화 테스트 1회 필수
- **(07-13)** auto-sync push 조용한 실패: 활성 gh 계정 sukeun8은 claude-config push 권한 없음 → `gh auth switch -u sukeun1997 && git push && gh auth switch -u sukeun8`. 훅 수정 필요 (2026-07-19 현재도 19회 실패 적체)
- **(07-13)** session-start health 경고 유실 버그 수정: _HEALTH_WARNINGS를 CONTEXT 초기화 이후로 이동, 가짜 마커 테스트로 확인

### Promoted 2026-07-20
- 하네스 진화 원칙 실증: 규칙 감축 기준 = "시스템 프롬프트 중복 / 구형 모델 가정 / 상호 충돌" 3분류. 다음 모델 업그레이드 시 동일 절차 재적용

### Promoted 2026-07-20
- Slack 캡처 이름 모자이크 = 색기반 @멘션 자동검출 + 아바타열∩타임스탬프 conjunction 헤더검출. OCR 없이 재사용 가능

### Promoted 2026-07-21
- CMS 배분이체 착지 계좌 = get_repayment_service_account_number(가상계좌) = **상환예치계좌** (차입자수납 아님, cms_repayment_transfer_process.py:64). 완제 트리거(action_repayment_task)는 차입자수납 잔액 기준 — CMS 수납금을 완제에 쓰려면 상환예치→차입자수납 수동 이관 필요

### Promoted 2026-07-21
- transfer_1_to_1 예외 계약: BankTimeOut=무보상 전파(원장 차감 잔존), BankFailure/BankError/일반=내장 보상 후 재전파, 보상 자체 실패 시 원예외 소실·비Bank예외 전파 — 호출자가 Bank계열 예외만 "보상 확정"으로 신뢰 가능

### Promoted 2026-07-22
- KFTC 정산보고(원리금지급)는 banking-report 경유 아님 — inapi kftc_client v1이 금결원 직행 (utils/tasks/kftc.py:224,297 → settlement_mixin POST /investments/payment). 보고 상태 원장이 RISS/RIS.kftc_report_status 컬럼 → 목표1(보고 이관)과 목표3(레거시 제거) 강결합. 7/12 문서의 "complete_process→banking_report_client 중계" 서술은 코드에서 미확인(정정)

### Promoted 2026-07-22
- 정산 모델은 3세대: 1세대 showcase(RISS/RIS 등, 제거 대상) / 2세대 inapi moneyflow(SettlementSchedule·LPNS·LPN, projection 강등) / 3세대 pfct-settlement(정본). InvestmentNote는 투자 포지션 원장으로 별개 존치
