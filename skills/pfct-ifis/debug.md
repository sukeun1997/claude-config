---
name: debug
description: "Use when encountering bugs, test failures, build errors, or unexpected behavior. Automates debugger agent dispatch with model routing (sonnet/opus) based on difficulty, failure reproduction via TDD, fix implementation, and verification pipeline."
user_invocable: true
---

# Debug Skill - Automated Debugging Pipeline

문제 발생 시 난이도를 판단하고, 적절한 모델의 debugger를 투입하여 근본 원인 분석 → 재현 테스트 → 수정 → 검증까지 자동으로 파이프라인을 실행합니다.

## 워크플로우

```
문제 입력
  │
  ├─ 1. 문제 분류 & 난이도 판정
  │     ├─ LOW: 단일 파일, 명확한 에러 메시지
  │     ├─ MID: 2-5 파일, 모듈 간 상호작용
  │     └─ HIGH: 6+ 파일, 아키텍처/동시성/비결정적 문제
  │
  ├─ 2. Debugger 에이전트 투입 (난이도별 모델 선택)
  │     ├─ LOW/MID → debugger (sonnet)
  │     └─ HIGH → debugger (opus) + architect (opus) 병렬
  │
  ├─ 3. 근본 원인 확정 → 사용자 확인
  │
  ├─ 4. 실패 재현 테스트 작성 (RED)
  │
  ├─ 5. 수정 구현 (GREEN)
  │
  ├─ 6. 검증 (빌드 + 테스트)
  │
  └─ 7. 결과 보고
```

## 실행 단계

### Step 1. 문제 수집 & 분류

사용자로부터 아래 정보를 수집합니다 (이미 제공된 정보는 생략):

- **증상**: 에러 메시지, 스택 트레이스, 예상과 다른 동작
- **재현 조건**: 어떤 상황에서 발생하는지
- **최근 변경**: 문제 발생 전 변경된 코드가 있는지

### Step 2. 난이도 판정 & 모델 라우팅

아래 기준으로 난이도를 자동 판정합니다:

| 난이도 | 기준 | 투입 에이전트 |
|--------|------|--------------|
| **LOW** | 단일 파일, 명확한 에러 (NPE, 타입 오류, 컴파일 에러) | `debugger` (sonnet) |
| **MID** | 2-5 파일 관련, 모듈 간 상호작용, 테스트 실패 | `debugger` (sonnet) |
| **HIGH** | 6+ 파일, 동시성/비결정적 문제, 아키텍처 이슈, Kafka/이벤트 흐름 | `debugger` (opus) |

**사용자 오버라이드**: 사용자가 "opus로 해줘" 또는 "깊이 분석해줘"라고 요청하면 난이도와 무관하게 opus 사용.

**HIGH 난이도 병렬 투입**:
```
HIGH 판정 시:
  → debugger (opus): 근본 원인 분석 + 스택 트레이스 역추적
  → architect (opus): 아키텍처 관점 영향 범위 분석 (READ-ONLY)
  두 결과를 종합하여 근본 원인 확정
```

### Step 3. Debugger 에이전트 프롬프트

debugger 에이전트에 아래 형식으로 위임합니다:

```
## 문제
{증상 요약}

## 재현 조건
{재현 방법}

## 최근 변경
{관련 변경 내역 또는 git diff}

## 분석 요청
1. 에러 메시지/스택 트레이스를 정확히 읽고 근본 원인을 추적하라
2. 관련 코드를 읽고 데이터 흐름을 추적하라
3. 가설을 세우고 증거로 검증하라
4. 3회 이상 다른 접근이 실패하면 시도 내역을 정리하라

응답 형식:
- **결과**: SUCCESS | PARTIAL | FAILED
- **근본 원인**: 1-3줄 요약
- **영향 파일**: [파일 경로 목록]
- **수정 방향**: 제안하는 수정 전략
- **미해결 사항**: 확인하지 못한 부분 (없으면 "없음")
```

### Step 4. 근본 원인 확인

debugger 결과를 사용자에게 보고합니다:

```
📋 근본 원인 분석 결과
- 원인: {근본 원인 요약}
- 영향 범위: {파일 목록}
- 수정 방향: {제안}

이 분석이 맞다면 재현 테스트 → 수정으로 진행할까요?
```

**사용자 승인 후** 다음 단계로 진행합니다.

### Step 5. 실패 재현 테스트 (RED)

근본 원인을 재현하는 테스트를 작성합니다:

- kotest + mockk 사용 (프로젝트 컨벤션)
- 테스트가 **실패하는 것을 확인** (RED 상태)
- 테스트 실행: `./gradlew :<모듈>:test --tests "*TestClassName" -x ktlintCheck -x ktlintMainSourceSetCheck -x ktlintTestSourceSetCheck -x ktlintFormat`

### Step 6. 수정 구현 (GREEN)

- 근본 원인에 대한 **최소한의 수정**만 적용
- 수정 후 재현 테스트가 **통과하는 것을 확인** (GREEN 상태)
- 불필요한 리팩토링이나 주변 코드 정리 금지

### Step 7. 검증

변경 규모에 따라 자동 검증 수준을 선택합니다:

| 변경 규모 | 검증 |
|-----------|------|
| 1-2 파일 | 변경 모듈 `compileKotlin` + 해당 테스트 |
| 3-5 파일 | 변경 모듈 전체 테스트 |
| 6+ 파일 | 전체 빌드 + 테스트 + code-reviewer |

```bash
# 모듈 테스트
./gradlew :<모듈>:test -x ktlintCheck -x ktlintMainSourceSetCheck -x ktlintTestSourceSetCheck -x ktlintFormat

# 전체 빌드 (대규모)
./gradlew build -x ktlintCheck -x ktlintMainSourceSetCheck -x ktlintTestSourceSetCheck -x ktlintFormat -PskipFetchAvro --no-daemon
```

### Step 8. 결과 보고

```
✅ 디버깅 완료
- 근본 원인: {요약}
- 수정 내용: {변경 파일 및 핵심 변경}
- 검증: 빌드 ✅ / 테스트 ✅ ({통과 수}/{전체 수})
- 재현 테스트: {테스트 클래스명}
```

## 빌드 실패 전용 단축 경로

빌드/컴파일 에러는 debugger 대신 `build-fixer`를 직접 투입합니다:

```
빌드 에러 감지
  → build-fixer (sonnet): 최소 diff로 수정
  → 빌드 재확인
  → 실패 시 debugger 에스컬레이션
```

## 3회 실패 에스컬레이션

동일 문제에 3회 다른 접근이 실패하면:

1. 시도 내역을 테이블로 정리
2. 현재 모델이 sonnet이면 → opus로 업그레이드 제안
3. 이미 opus면 → 사용자에게 방향 확인 요청
4. `/codex:codex-rescue`로 Codex 2차 진단 제안

## 주의사항

- **Sentry 제외**: 현재 Sentry MCP가 동작하지 않으므로 Sentry 관련 도구는 사용하지 않음
- **테스트 우회 금지**: @Ignore, skip 등으로 실패 테스트를 비활성화하지 않음
- **최소 수정 원칙**: 버그 수정에 리팩토링을 섞지 않음
- **REQUIRED BACKGROUND**: `superpowers:systematic-debugging`의 4단계 분석법을 내부적으로 따름
