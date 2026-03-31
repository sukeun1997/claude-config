# Agent Orchestration

## Agent Catalog

**Source of Truth**: `~/.claude/agents/*.md` (30개 정의 파일)

각 에이전트의 역할·모델·도구 제약은 해당 `.md` 파일의 YAML frontmatter에 정의되어 있다.
이 문서에는 카탈로그를 중복 유지하지 않는다.

## Agent 선택 가이드

```
사용자 요청 → 어떤 에이전트?
├─ "탐색/검색" → Explore (haiku)
├─ "설계/아키텍처" → architect (opus)
├─ "계획 세워줘" → planner (opus)
├─ "구현/수정" → executor (sonnet) 또는 deep-executor (opus)
├─ "리뷰" → Expert Pool (아래 참조)
├─ "버그 수정" → debugger (sonnet) → executor (sonnet)
├─ "테스트" → test-engineer (sonnet)
├─ "빌드 실패" → build-fixer (sonnet)
└─ "문서" → writer (haiku)
```

## Review Expert Pool (변경 규모별 리뷰어 선택)

리뷰 시 항상 3명 병렬이 아니라, **변경 규모에 따라 최적 리뷰어를 선택**한다.

| 변경 규모 | 리뷰어 | 근거 |
|-----------|--------|------|
| 소규모 (≤2파일, <50줄) | code-reviewer 1명 | 보안/품질 이슈 가능성 낮음 |
| 중규모 (3-5파일, 50-200줄) | code-reviewer + quality-reviewer | 로직 결함 가능성 증가 |
| 대규모 (6+파일, 200줄+) | code-reviewer + security-reviewer + quality-reviewer (병렬) | 전면 리뷰 필요 |

### 보안 민감 경로 예외 (규모 무관 security-reviewer 필수)

아래 경로가 변경에 포함되면 **규모와 무관하게** security-reviewer를 추가한다:
- `client/` (외부 API 클라이언트 15개)
- `*Security*`, `*Auth*`, `*Token*` 패턴
- `config/application*.yml` (시크릿/인증 설정)
- `*Vault*`, `*Credential*` 패턴

## Parallel Execution

독립 작업은 반드시 병렬 Task 호출. 순차 실행이 필요한 경우는 CLAUDE.md §2 참조.

## Immediate Agent Usage (사용자 요청 없이 자동 실행)

1. 복잡한 기능 요청 → **planner**
2. 코드 작성/수정 완료 → **code-reviewer**
3. 버그 수정/신규 기능 → TDD 스킬 (`/springboot-tdd`, `/tdd`)
4. 아키텍처 결정 → **architect**
5. 구현 완료 보고 시 → **verifier** (아래 자동 검증 위임 참조)

## 자동 검증 위임 (Auto-Verification Delegation)

구현 작업이 완료되면 **사용자가 `/vc`를 호출하지 않아도** 아래 검증을 자동 실행한다.

### 트리거 조건
- `executor` 또는 `deep-executor`가 SUCCESS로 완료 보고
- 메인에서 직접 2개 이상 파일을 수정 완료
- TDD 루프에서 모든 테스트 통과 후

### 자동 검증 체인
```
구현 완료
  → verifier (빌드 + diff 검증)
  → 실패 시: build-fixer 자동 투입 → 재검증
  → 성공 시: 사용자에게 결과 보고
```

### 검증 수준 (규모별 자동 선택)
| 변경 규모 | 검증 수준 | 수행 내용 |
|-----------|-----------|-----------|
| 소규모 (≤2파일, <50줄) | **Light** | `compileKotlin`만 확인 |
| 중규모 (3-5파일, 50-200줄) | **Standard** | 빌드 + 변경 모듈 테스트 |
| 대규모 (6+파일, 200줄+) | **Full** | 빌드 + 테스트 + code-reviewer (§3 Verification Flow와 동일) |

### Re-Review 루프 (대규모 변경 전용)

Full 검증 수준(6+파일, 200줄+)에서 code-reviewer가 **CRITICAL 또는 HIGH** 이슈를 보고한 경우:

```
code-reviewer 피드백 (CRITICAL/HIGH)
  → executor가 피드백 반영
  → verifier 빌드 확인
  → 같은 code-reviewer에 SendMessage로 재확인 (해당 이슈만 focused review)
```

- **최대 1회** 재확인 (무한 루프 방지)
- 소규모/중규모 변경에서는 적용하지 않음
- re-review에서도 CRITICAL 잔존 시 → 사용자에게 보고 (자동 재시도 금지)

### 생략 조건
- 문서/설정 파일만 수정한 경우
- 사용자가 "검증 스킵" 명시
- 이미 `/vc` 또는 `/springboot-verification`을 수동 실행한 경우

## Sprint Contract (executor 위임 시 완료 조건 사전 명시)

executor/deep-executor에 작업을 위임할 때, 프롬프트에 아래 **완료 조건**을 포함한다:

```
완료 조건:
1. [기능적 조건]: 무엇이 동작해야 하는가
2. [기술적 조건]: 빌드/테스트 통과 기준
3. [제외 범위]: 이 스프린트에서 하지 않을 것
```

- verifier는 이 완료 조건을 기준으로 SUCCESS/PARTIAL/FAILED를 판정한다
- 완료 조건이 없는 위임은 verifier가 빌드+diff만 확인한다 (기존 동작 유지)
- 완료 조건은 **코딩 시작 전** 확정한다 (중간 변경 금지)

> Structured Response Contract(아래)는 "결과 보고 형식(출력)"이고, Sprint Contract는 "완료 기준(입력)"이다. 두 가지를 함께 사용한다.

## Sub-Agent 결과 검증 (Silent Failure Prevention)

### 검증 루프 (executor/deep-executor 완료 후 자동)

`executor` 또는 `deep-executor`가 구현 완료를 보고하면, **반드시 `verifier`를 후속 실행**한다:

```
executor 완료 → verifier 자동 실행 → 실패 시 executor 재투입
```

verifier가 확인할 항목:
- 변경된 파일이 실제로 존재하는지 (빈 결과/hallucination 감지)
- 빌드가 통과하는지 (`./gradlew :<모듈>:compileKotlin`)
- executor가 보고한 변경 사항과 실제 diff가 일치하는지

### 구조화된 응답 강제 (Structured Response Contract)

서브에이전트에 작업을 위임할 때, 프롬프트 말미에 아래 응답 형식을 포함한다:

```
응답 형식:
- **결과**: SUCCESS | PARTIAL | FAILED
- **변경 파일**: [파일 경로 목록] (없으면 "없음")
- **핵심 내용**: 1-3줄 요약
- **미해결 사항**: 완료하지 못한 부분 (없으면 "없음")
```

이 형식이 없는 서브에이전트 응답은 **불완전한 결과로 간주**하고, 추가 확인 후 사용자에게 보고한다.

### 적용 범위

| 에이전트 | 검증 루프 | 구조화 응답 |
|----------|-----------|------------|
| `executor`, `deep-executor` | 필수 | 필수 |
| `build-fixer` | 필수 (빌드 재확인) | 필수 |
| `debugger` | 권장 | 필수 |
| `Explore`, `writer` | 불필요 | 권장 |
| Review 계열 (`code-reviewer` 등) | 불필요 | 불필요 (자체 형식) |
