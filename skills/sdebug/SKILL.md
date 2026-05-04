---
name: sdebug
description: "버그/장애에 대해 systematic-debugging Phase 1-4를 자동 적용해 근본 원인을 추적. --flow 옵션 시 코드 흐름·커밋 로그까지 분석해 전체 처리 과정과 해결안을 docs-save로 저장. Use when user says '/sdebug', 'sdebug', '체계적 디버깅', '플로우 분석', 'flow 분석'."
---

# sdebug — Systematic Debugging + Flow 분석

`superpowers:systematic-debugging` 방법론을 진입점으로 감싸는 스킬. 기본 모드는 근본 원인 추적, `--flow` 모드는 코드 흐름 전체를 정리하고 분석 문서를 vault에 저장한다.

## Arguments

- `<증상/이슈 설명>`: 자연어로 작성된 문제 설명 (스택트레이스, 로그, 재현 시나리오 등 포함 가능)
- `--flow`: 단순 원인 추적을 넘어 호출 체인·처리 과정·관련 커밋까지 분석하고 결과를 `/docs-save`로 저장
- `--no-save`: `--flow` 사용 시에도 docs-save 단계 생략 (분석만 출력)

## When to Apply

- `/sdebug ...` 호출 시
- 사용자가 "이 버그 원인 좀 봐줘", "왜 이렇게 동작해?" 류로 물을 때 — 단, 단순 1파일 fix면 시스템 권장 흐름(`superpowers:systematic-debugging` 직접 invoke)을 따름
- "전체 처리 과정 정리해줘", "flow 분석", "어디가 문제인지 그림 그려줘" → `--flow` 모드

## 전제 조건

- 프로젝트 cwd에서 실행 (git 저장소면 커밋 로그 활용 가능)
- 증상이 모호하면(예: "안 돼요") 먼저 사용자에게 재현 시나리오/에러 메시지/관련 모듈을 1번만 묻고 진행

---

## Pipeline (기본 모드)

`superpowers:systematic-debugging` 스킬을 invoke하여 Phase 1-4를 순차 실행한다.

### Phase 1: Root Cause Investigation
- 에러 메시지/스택트레이스 정독
- 재현 가능성 확인 (재현 시나리오 정리)
- 최근 변경 검토: `git log --oneline -20 <관련 파일>`
- 다층 시스템이면 컴포넌트 경계마다 증거 수집 (입력/출력/환경)
- 데이터 흐름 역추적: 잘못된 값의 발원지까지

### Phase 2: Pattern Analysis
- 동일 코드베이스에서 정상 동작하는 유사 코드 비교
- 차이점 나열 (사소한 것도 포함)

### Phase 3: Hypothesis & Testing
- 가설 1개를 명시적으로 서술 ("X가 원인이라고 본다, 이유는 Y")
- 최소 변경으로 검증

### Phase 4: Implementation
- 실패하는 테스트 케이스 작성
- 단일 수정 적용
- 검증 → 실패 시 Phase 1 복귀, 3회 실패 시 아키텍처 의심

### 출력 포맷 (기본 모드)

```
## 근본 원인 분석

**증상**: {증상 요약}
**재현**: {재현 절차 또는 "단발성"}
**최근 변경**: {관련 커밋 또는 "없음"}

### 호출 체인
{스택트레이스 또는 추적된 호출 경로}

### 가설
{명시적 1개 가설}

### 수정 방향
{파일/메서드/변경 내용 구체적으로}

> 이 방향으로 수정을 진행할까요?
```

사용자 승인 후 코드 수정 → 검증 → 완료.

---

## Pipeline (`--flow` 모드)

근본 원인을 넘어 **전체 처리 과정**을 정리하고 vault에 저장한다.

### Phase F1: 진입점 식별
- 사용자 설명에서 진입점 후보 추출 (API endpoint, Celery task, 이벤트 핸들러, CLI 명령 등)
- `Grep`/`Glob`으로 진입점 위치 확정
- 모호하면 사용자에게 "이 흐름은 {A} / {B} 중 어느 쪽인가요?" 1회 질문

### Phase F2: 코드 흐름 추적

`superpowers:systematic-debugging`의 root-cause-tracing 기법을 forward 방향으로 적용:

1. 진입점 함수를 Read
2. 호출하는 함수/메서드를 따라가며 5-7단계까지 추적 (또는 외부 경계 도달까지)
3. 각 단계에서 기록할 것:
   - 파일:라인
   - 함수 시그니처
   - 핵심 로직 1-2줄 요약
   - 분기 조건 (있다면)
   - 외부 호출 (DB/API/큐/캐시)
4. 탐색이 5-7개 파일을 넘어가면 **`Explore` 서브에이전트에 위임** (haiku, "report in under 3000 characters")

### Phase F3: 커밋 로그 검토 (조건부)

아래 조건에 해당하면 `git log`/`git blame`으로 변경 이력 확인:

- 분기 조건이나 예외 처리에 "왜 이렇게 짜여 있는지" 주석/문맥이 부족할 때
- 최근 변경된 파일이 흐름에 포함될 때 (`git log --since="2 weeks ago" -- <files>`)
- 특정 라인의 의도가 불명확할 때 → `git blame -L <start>,<end> <file>` → 해당 커밋 메시지 확인

수집한 커밋 메시지에서 **"왜"**를 추출하여 흐름 설명에 주입.

### Phase F4: 종합 정리

다음 구조로 분석 문서를 작성한다 (마크다운, 임시 파일 `/tmp/sdebug-flow-{slug}-{YYYY-MM-DD}.md`):

```markdown
# {주제} 처리 흐름 및 문제 분석

## 1. 개요
- **증상**: {1-2줄}
- **진입점**: {파일:라인, 함수명}
- **분석 범위**: {탐색한 파일 수, 호출 깊이}

## 2. 전체 처리 흐름

### Step 1. {단계 이름} — `path/file.py:123`
{핵심 로직 1-2줄}
- 분기: {조건이 있다면}
- 외부: {DB/API 호출이 있다면}

### Step 2. ...

(텍스트 다이어그램으로 호출 체인 표현)
```
A.entry()
  └─ B.process()
       ├─ C.validate()  ✗ 여기서 실패
       └─ D.persist()
```

## 3. 관련 커밋 (선택)
- `<sha>` {date} — {message 요약, 의도}

## 4. 문제 지점
- **어디**: {파일:라인}
- **왜**: {코드 흐름·커밋 의도 종합}
- **어떻게 드러나는가**: {증상 ↔ 코드 매핑}

## 5. 해결 방향
### Option A: {접근법 1}
- 변경 파일: ...
- 트레이드오프: ...

### Option B: {접근법 2}
- ...

### 권장
{Option A/B 중 어떤 것을 추천하고 그 이유}

## 6. 검증 계획
- 단위 테스트: ...
- 수동 재현: ...
- 회귀 위험 영역: ...
```

### Phase F5: 보고 + docs-save

1. 위 문서 내용을 사용자에게 출력 (요약 우선, 전체는 임시 파일 경로 안내)
2. **`/docs-save {임시파일경로}`** 호출
   - `--no-save` 플래그가 있으면 생략
   - docs-save가 `~/vault/project/{project}/{branch}/`에 저장하면서 `analysis-{topic}-{YYYY-MM-DD}.md` 형태로 리네임
3. 저장 완료 메시지 + "이 분석을 바탕으로 수정을 진행할까요?" 게이트
4. 사용자가 승인하면 권장안 따라 구현 → 기본 모드의 Phase 4 흐름으로 합류

---

## 위임 정책

- 코드 흐름 탐색이 5+파일이거나 깊이 7단계+ → `Explore`(haiku)에 위임, "report under 3000 chars"
- 구현 단계가 3+파일 변경 → `executor`(sonnet)에 위임 + Sprint Contract 명시
- 분석 결과 검증이 필요한 고위험 영역(보안/스키마/배포) → `code-reviewer` + 해당 도메인 reviewer 추가

## 출력 형식 (Structured Response Contract)

분석 종료 시:

- **결과**: SUCCESS | PARTIAL | FAILED
- **변경 파일**: 분석 단계는 `없음`, 수정 단계는 경로 목록
- **핵심 내용**: 1-3줄
- **미해결 사항**: 후속 조사 필요한 가설
- **검증**: 재현 확인/빌드/테스트

## 예시

```
/sdebug 정산 6100 전문 실패 시 재시도 동작 확인
→ 기본 모드: settlement.py 재시도 로직 추적, 가설 제시, 수정 방향 제안

/sdebug --flow 정산 처리 전체 흐름 정리 + 6100 실패 케이스
→ flow 모드: Celery task → BankFailure → retry 정책까지 단계별 정리,
   커밋에서 "왜 max_retries=2인지" 추출, 문제·해결안 제시, vault 저장

/sdebug --flow --no-save 동일하게 분석하되 저장 생략
```
