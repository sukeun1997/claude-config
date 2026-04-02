---
name: absorbed-articles
description: "/absorb 스킬로 분석한 외부 아티클 이력. 어떤 아티클에서 무엇을 적용했는지 추적."
type: reference
---

# Absorbed Articles

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
