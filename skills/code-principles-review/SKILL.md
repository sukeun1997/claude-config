---
name: code-principles-review
description: "Use when verifying an implementation, PR, or diff against the user's good-code judgment principles (좋은 코드의 판단 원칙 vault doc) — for Kotlin/Spring or Python/Django changes, when the user asks '원칙대로 구현됐는지', '좋은 코드인지 확인', or from /ecr and python-deep-review quality passes."
---

# Code Principles Review

vault 문서 **"좋은 코드의 판단 원칙 - Kotlin Spring과 Django Python"**을 정본 rubric으로
diff/PR을 항목별 판정하는 스킬. 판정은 반드시 근거(file:line)와 함께.

## 정본 문서 (판정 전 Read 필수)

```
/Users/sukeunpark/vault/30 학습/개념/기술/좋은 코드의 판단 원칙 - Kotlin Spring과 Django Python.md
```

경로에 공백 있음 — bash에서 반드시 인용. 아래 체크리스트는 요약본이며,
판정 근거가 애매하거나 원칙이 충돌하면 정본의 해당 섹션(특히 "원칙이 충돌할 때
판단하는 법" 표)을 읽고 판정한다. 서브에이전트에 위임할 때는 이 경로를
프롬프트에 그대로 전달해 직접 Read하게 한다 (메인이 요약해 옮기지 않는다).

## 판정 절차

1. 정본 문서 Read → 대상 diff/PR Read (주변 코드 필요 시 fetch)
2. **판단 기준 8가지**를 각각 PASS / CONCERN / FAIL 판정
3. **실무 체크리스트 4축** 판정
4. 원칙 충돌 지점은 충돌표 기준으로 트레이드오프 판정 (기계적 지적 금지)
5. CONCERN/FAIL은 "이번 PR에서 수정" vs "후속 과제" 구분

## 판단 기준 8가지 (정본 §가장 먼저 외울 판단 기준)

1. 책임을 한 문장으로 설명 가능한가
2. happy path가 위에서 아래로 읽히는가 (guard clause 선행)
3. 동일 업무 규칙이 여러 곳에 흩어져 있지 않은가
4. 이름만으로 도메인 의도가 드러나는가 (CQS — 이름과 side effect 일치)
5. DB 변경·외부 호출·메시지 발행 등 side effect가 명확한가
6. transaction, concurrency, invariant를 어디서 보장하는가
   — application check로만 보장하는 invariant는 DB constraint 가능 여부를 반드시 짚는다
7. 테스트가 내부 구현이 아니라 관찰 가능한 행동을 검증하는가
8. 지금의 추상화가 실제 요구에서 나왔는가 (AHA/Rule of Three/YAGNI)

## 실무 체크리스트 4축 (정본 §실무 적용 체크리스트)

- **읽기**: 이름·guard clause·추상화 수준 일관성
- **책임과 경계**: 변경 이유 단일성, 외부 DTO↔내부 모델 경계 변환
- **상태와 데이터**: 불가능한 상태 차단, invariant의 DB constraint 검토,
  transaction/lock이 실제 경쟁 구간을 덮는가, 재시도 멱등성
- **테스트와 운영**: 행동 검증, N+1/발생 SQL, 로그≠처리 완료, 실패 의미 보존

## 출력 형식

```md
### 원칙 판정표
| # | 기준 | 판정 | 근거 (file:line) |

### 체크리스트 판정 (읽기/책임과 경계/상태와 데이터/테스트와 운영)

### CONCERN/FAIL 상세
각각: 근거 + 수정 방향 + 이번 PR vs 후속

### Non-blocking
취향 수준·80% 미만 확신 항목
```

## 운용 규칙

- 80% 미만 확신은 CONCERN으로 올리지 않고 Non-blocking으로
- 원칙 이름을 인용하는 것만으로 finding이 되지 않는다 — 그 원칙이 막아주는
  다음 버그/변경 비용을 구체적으로 명시해야 CONCERN/FAIL 자격
- `/ecr`·`python-deep-review` 파이프라인에서는 quality 계열 에이전트 1개에
  이 스킬을 로드시켜 판정표를 받고, 다른 에이전트와 중복 지적은 통합한다
- 완전한 도메인 모델 스케치가 필요하면 `domain-modeling-gate`로 (여기서 작성 금지)
