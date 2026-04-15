---
name: absorbed-articles
description: "/absorb 스킬로 분석한 외부 아티클 이력. 어떤 아티클에서 무엇을 적용했는지 추적."
type: reference
---

# Absorbed Articles

### 2026-04-14 (2): shanraisshan/claude-code-best-practice — agent/skill frontmatter 필드 3종
- **URL**: https://github.com/shanraisshan/claude-code-best-practice
- **유형**: best-practice reference (42.9k stars, Boris Cherny 스타일 CC 패턴 카탈로그)
- **적용**: 32건 (skill 3: user-invocable:false 숨김 — kotlin-patterns/redis-cache-patterns/haru-infra / agent 28: color 필드 7색 역할 클러스터 / agent 2: effort:max — verifier/critic)
- **보류**: 3건 (G2 agent `skills:` 프리로딩 — 프롬프트 주입 대안 존재, G6 skill `paths:` glob — 공식 지원 미확인, G9 Stop 훅 exit 2 nudge — 무한 루프 리스크 + CLAUDE.md §1 중복)
- **제외 (pre-filter)**: 4건 (agent hooks 필드, context:fork, startup-flags --init-only, PostToolUse formatter — 환경 불일치/기존 구조 중복/프로젝트별)
- **핵심 인사이트**: 28개 에이전트가 `color` 필드 0건 사용 → 병렬 실행 로그 가독성 gap. 60+ 스킬 중 `user-invocable` 0건 → `/` 메뉴에 참조 전용 스킬 노출로 노이즈. frontmatter 미지원 필드는 무시되므로 적용 비용은 낮지만, `paths:` glob 자동 활성화와 `skills:` 프리로딩은 공식 지원이 불명이라 보류가 안전. **Opus 검증이 "즉시 적용 2건 + 점진적 1건 + 보류 3건"으로 과욕 차단**하여 /absorb 신호 품질 상승.

### 2026-04-14: Karpathy-Inspired Claude Code Guidelines (4 Principles)
- **URL**: https://github.com/forrestchang/andrej-karpathy-skills
- **유형**: opinion + guideline (Karpathy의 LLM 코딩 실패 관찰 기반 CLAUDE.md 템플릿)
- **적용**: 2건 (guideline §1: Disambiguation & Pushback 3개 bullet, guideline §5: 변경 최소화 소섹션 6개 rule)
- **스킵**: 1건 (D. 메인 세션용 mini Sprint Contract — Opus 권장에 따라 다음 사이클로 보류: A/B 적용 후 friction 모니터링 필요)
- **이미 적용 중**: Simplicity First 5항목 (시스템 기본 프롬프트 + §5 Coding Standards), State assumptions (§1 추측 금지 + 증거 먼저 + 환경 확인), Goal-Driven Execution (verification.md Sprint Contract + superpowers:systematic-debugging)
- **핵심 인사이트**: 기존 CLAUDE.md는 "에이전트 위임/검증 인프라" 중심이라 *메인 세션 직접 작업* 시의 절제 규칙에 gap. Karpathy의 "묵시적 해석 금지 + pushback + 변경 추적성" 원칙은 시간 순서상 "결정 전 질문 → 결정 후 밀고 나감"의 앞쪽 반을 채움. dead code "언급만, 삭제 금지"는 over-cleanup 경향 억제 효과.

### 2026-03-25: Harness Design for Long-Running Application Development
- **URL**: https://www.anthropic.com/engineering/harness-design-long-running-apps
- **유형**: engineering-blog
- **적용**: 4건 (guideline 3, memory 1)
- **스킵**: 0건
- **핵심 인사이트**: 하네스의 모든 컴포넌트는 모델 한계에 대한 가정 — 모델 발전에 따라 가정을 재검토하고, 구현/평가를 분리하면 품질이 올라간다

### 2026-03-28: Claude Code 활용 리포트 Friction 섹션 (3/14~3/28)
- **URL**: file:///Users/sukeun/.claude/usage-data/report.html#friction
- **유형**: usage-report (자체 분석)
- **적용**: 5건 (guideline 4, skill-routing 1)
- **스킵**: 1건 (architecture: 생성-검증 루프 패턴)
- **핵심 인사이트**: 상위 friction은 가설 기반 추측 진단(29건)과 재현 없는 버그 수정(24건). 증거 먼저 + 재현→진단→수정 순서 + 탐색 상한 + 환경 확인 우선 규칙으로 대응

### 2026-04-02: Universal Claude.md – Claude 출력 토큰 절감
- **URL**: https://news.hada.io/topic?id=28077
- **유형**: engineering-blog + tutorial
- **적용**: 1건 (guideline 1)
- **스킵**: 3건 (이미 적용 3: CLAUDE.md 규칙 파일, 계층적 병합, 프로필 선택)
- **핵심 인사이트**: CLAUDE.md에 간결성 규칙으로 출력 토큰 ~63% 절감 가능하나, "답 먼저" 규칙은 transformer 자기회귀 구조와 충돌 가능. 대규모 에이전트 루프에서 누적 절감 효과가 크지만, learning mode와 공존하려면 서브에이전트 파이프라인에만 한정 적용이 적절

### 2026-04-06: Context Mode - Claude Code의 컨텍스트 소비를 98% 줄이는 MCP 서버
- **URL**: https://news.hada.io/topic?id=27108
- **유형**: engineering-blog + case-study
- **적용**: 2건 (guideline 2: MCP 출력 최소화 + MCP 도구 감사)
- **스킵**: 1건 (architecture: Context Mode MCP 서버 도입 — deferred loading + 서브에이전트 격리로 대체 가능)
- **보류**: 1건 (guideline: 프롬프트 캐시 안정성 — rules/common 수준으로 강등, 측정 메트릭 부재)
- **핵심 인사이트**: MCP 출력은 컨텍스트의 숨은 팽창 원인. 호출 시 범위 한정 + 주기적 도구 감사로 제어. 프로세스 격리는 서브에이전트 위임으로 대체 가능. GitHub/Context7 이중 등록 31개 중복 발견

### 2026-04-08: 코드 에이전트 오케스트라 — 멀티 에이전트 코딩 가이드
- **URL**: https://addyosmani.com/blog/code-agent-orchestra/
- **유형**: engineering-blog + tutorial
- **적용**: 1건 (guideline 1: 에이전트 교착 3회 종료)
- **스킵**: 14건 (already_applied: 서브에이전트/팀/모델라우팅/워크트리/플랜승인/훅/검증분리 등)
- **보류**: 1건 (architecture: Ralph Loop 야간 실행 — FD 설계 선행 필요)
- **핵심 인사이트**: 현재 하네스가 Addy Osmani의 멀티에이전트 패턴 대부분을 이미 커버. 에이전트 교착 자동 종료와 AGENTS.md 인간 작성 원칙만 gap. "모호한 스펙은 수십 개 병렬 에이전트에 오류를 증폭시킨다"

### 2026-04-07: Claude Code 2월 업데이트 이후 품질 저하 분석
- **URL**: https://github.com/anthropics/claude-code/issues/42796
- **유형**: case-study + opinion
- **적용**: 4건 (setting 1: cleanupPeriodDays 365, guideline 1: Stop Phrase 금지 목록, hook 1: tool-tracker Read 카운트 수집, skill 1: review-week Convention Drift 체크)
- **스킵**: 4건 (already_applied: effortLevel high, 조기 중단 금지, edit-tracker 삽질 감지 / 보류: Hook 기반 Stop Phrase 자동 감지 — API 제약)
- **핵심 인사이트**: Thinking 깊이 감소·Read:Edit 비율·Stop phrase 빈도·Convention drift는 품질 저하 조기 경보 지표. 이 지표를 자동 수집하여 /review-week에서 추세 분석하면 모델 변경에 의한 점진적 품질 저하를 감지 가능

### 2026-04-06: Devil's Advocate skill — adversarial challenge at every step
- **URL**: https://reddit.com/r/ClaudeCode/comments/1scxd53/
- **유형**: showcase + discussion
- **적용**: 2건 (guideline 1: Pre-implementation Plan Challenge, memory 1: 기록)
- **스킵**: 2건 (already_applied: post-impl review §4, santa-loop / conflict: 별도 LLM judging — 단일 제공사 환경)
- **핵심 인사이트**: 동의 편향은 post-impl 리뷰로는 불충분. planner의 plan에 대한 confirmation bias를 pre-implementation critic으로 견제. 별도 서브에이전트에 adversarial 역할 명시 + 원본 데이터 재분석(steelmanning)이 핵심

### 2026-04-06: 71.5x token reduction by compiling raw folder into knowledge graph
- **URL**: https://reddit.com/r/ClaudeCode/comments/1sdaakg/
- **유형**: showcase + discussion
- **적용**: 1건 (memory 1: 기록)
- **스킵**: 1건 (architecture: graphify 도구 도입 — 4계층 메모리 + Explore 위임으로 대체)
- **보류**: 2건 (guideline: Stale Map Refresh — 훅 구현 없이 규칙만으로 실행 보장 불가, Frontmatter Navigation 강화 — topic 5개로 ROI 부족)
- **핵심 인사이트**: pre-compiled knowledge vs re-reading files 접근법은 커뮤니티에서 양면 평가. "just read the code bro" 의견이 높은 공감. 현재 4계층 메모리가 지식 그래프와 동등 역할 수행 중. 장기 브랜치에서 구조 파일 stale 방어가 실제 gap

### 2026-04-04: The Most Important Ideas in AI Right Now (April 2026)
- **URL**: https://danielmiessler.com/blog/the-most-important-ideas-in-ai
- **유형**: opinion/analysis
- **적용**: 4건 (guideline 3, memory 1)
- **스킵**: 0건
- **핵심 인사이트**: Intent-First(이상 상태 정의 없이는 도구가 무의미), Eval 기반 현재-이상 갭 측정으로 자율 최적화, 반복 스캐폴딩의 자동화 감지로 고가치 작업에 집중
