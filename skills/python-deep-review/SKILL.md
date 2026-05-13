---
name: python-deep-review
description: ".py 파일 변경 시 자동 발동되는 심층 리뷰 파이프라인. OOP/SOLID/추상화/중복제거 + 네이밍 + 상위 관점 리팩토링 제안 + 독립 컨텍스트 검증(verifier + critic). Use when user modifies .py files, says '/python-deep-review', '파이썬 리뷰', 'django 리뷰'."
---

# /python-deep-review — Python/Django 심층 리뷰 파이프라인

`.py` 파일 변경 시 자동 발동. 단순 "지금 동작하는가"가 아니라 OOP/SOLID/추상화/중복제거/네이밍 관점 + 별도 컨텍스트의 독립 검증까지 묶어 실행한다.

## When to Apply

- `.py` 파일 작성/수정 후 (글로벌 §4·§9 오토라우팅 트리거)
- `/python-deep-review` 또는 `/python-deep-review --light`
- 사용자가 "파이썬 리뷰", "django 리뷰", "OOP 관점도 봐줘" 등 요청

## Arguments

- `<path>` (optional): 리뷰 대상 파일/디렉토리. 미지정 시 변경된 `.py` 파일 전체
- `--light`: 경량 모드 (code-reviewer + critic만, Phase 1.5/2 단축)
- `--strict`: 가드 무시하고 전체 풀세트 강제
- `--skip-verify`: Phase 3 (verifier + critic) 생략

## 4가지 필수 관점 (모든 Phase에 명시 주입)

1. **OOP / SOLID / 추상화 / 함수 중복 제거 리팩토링**
   - SRP/OCP 위반, 같은 책임 분산, helper 추출 가치, 단계 분리(validate → execute 등)
   - "지금 동작하는가"가 아니라 "다음 사람이 고치기 좋게 짜여 있는가" 시각
2. **네이밍**
   - 함수/변수/상수가 도메인 의미와 추상화 수준에 맞는지
   - 호출부 의도를 가리지 않는지, 약어/축약 일관성, 부울/predicate 명명
3. **상위 관점 리팩토링 제안 (현재 동작 너머의 설계 시각)**
   - 즉시 머지 가능성과 별개로, PR 코멘트로 달 만한 OOP/SOLID/추상화 의견을 능동적으로 발굴
   - 예: 같은 mutation/함수 안에 인증/검증/실행/로그가 인라인이면 → validate → execute 단계 분리 제안
   - 예: 같은 루프가 두 번 돌면 → 통합 가능 여부
   - 예: 같은 분기 조건이 여러 곳에 등장하면 → 분기 dispatch / strategy 추상화 가능 여부
4. **독립 컨텍스트 검증** — Phase 3에서 verifier + critic이 fresh로 재검토 (Phase 1·2 결과 모르는 상태)

## Pipeline

```
Phase 0: Trivial Guard (default: OFF, --light에서만 활성)
  → diff 분석:
    - 주석/import/공백만 변경 → 안내 후 종료
    - 단일 파일 5줄 미만 → --light 강제 (code-reviewer + critic만)
    - 그 외 → Phase 1로
  ↓
Phase 1: 병렬 1차 리뷰 (4 agents, 동시 실행)
  → code-reviewer    (opus)   : 기본 코드 품질 + 버그
  → quality-reviewer (opus)   : OOP/SOLID/추상화/중복제거 — 관점 1
  → style-reviewer   (sonnet) : 네이밍 + Pythonic 관용구 — 관점 2
  → architect        (opus, READ-ONLY) : 상위 단계 추출/분리 제안 — 관점 3
  ↓
Phase 2: 사용자 1차 검토 (메인 세션이 결과 통합 + 사용자에게 요약 보고)
  → AUTO-FIX 후보 / ASK 후보 분리
  → 사용자 승인 대기
  ↓
Phase 3: 독립 컨텍스트 검증 (2 agents, 동시 실행, fresh context — 관점 4)
  → verifier (opus, 컨텍스트 0)
    프롬프트: "변경된 파일과 diff만 본다. 앞선 리뷰 결과를 모른다고 가정.
              빠진 OOP/네이밍/중복/추상화 이슈 잡아라"
  → critic (opus, 컨텍스트 0)
    프롬프트: "다음 리뷰 제안 목록을 adversarial하게 반박하라.
              과잉 추상화 / YAGNI 위반 / 트레이드오프 누락 / 단순 취향 의견을 골라내라"
  ↓
Phase 4: 최종 통합 + 사용자 결정
  → verifier 발견 추가 항목 + critic의 제안 약점 + Phase 2 통과 항목 → 통합 보고
  → 사용자 결정: 수정 진행 / 일부 보류 / 전체 보류
  ↓
Phase 5: 수정 (사용자 승인 시)
  → executor (sonnet) — 최소 diff
```

## 에이전트 모델 라우팅

| 에이전트 | 모델 | 역할 | Phase |
|---|---|---|---|
| code-reviewer | opus | 기본 품질·버그·경계조건 | 1 |
| quality-reviewer | opus | OOP/SOLID/추상화/중복 (관점 1) | 1 |
| style-reviewer | sonnet | 네이밍·Pythonic (관점 2) | 1 |
| architect | opus | 상위 단계 추출·설계 시각 (관점 3) | 1 |
| verifier | opus | 독립 재검증, 빠진 것 잡기 | 3 |
| critic | opus | 제안 약점·과잉 추상화 반박 | 3 |
| executor | sonnet | 최소 diff 수정 | 5 |

> §3 Model Routing의 기본 매핑을 따르되, 이 skill 내에서는 위 표가 우선.

## 프롬프트 템플릿 (각 Phase 1 에이전트 호출 시 공통 prefix)

```
[리뷰 대상]
<diff 또는 파일 경로>

[필수 관점 — 누락 시 리뷰 부족으로 간주]
1. OOP / SOLID / 추상화 / 함수 중복 제거
   - SRP/OCP 위반 지점, 책임 분산
   - validate → execute 같은 단계 추출 가능 여부
   - 같은 루프/분기 반복 → 통합/dispatch 추상화 여지
2. 네이밍 — 도메인 의미와 추상화 수준 일치성
3. "지금 동작하는가"가 아니라 "다음 사람이 고치기 좋은가" 시각

[응답 형식]
- 결과: SUCCESS | PARTIAL | FAILED
- AUTO-FIX (메인이 바로 적용해도 안전한 항목)
- ASK (사용자 판단 필요 — 트레이드오프 있는 항목)
- 상위 리팩토링 제안 (즉시 PR에는 안 들어가도 별도 PR로 추천)
```

## Phase 3 프롬프트 (독립 검증)

### verifier (컨텍스트 0)

```
[fresh context — 앞선 리뷰 결과 모름]
[리뷰 대상]
<diff 전체>

[과제]
앞선 리뷰가 있었다고 가정하고, 그 리뷰가 놓쳤을 만한 항목을 찾아라.
특히:
- OOP/SOLID 위반 중 미묘하거나 한 단계 안쪽 (예: helper 안의 helper)
- 네이밍 일관성 (한 변수만 다른 이름 패턴)
- 같은 분기/루프/조건이 다른 파일에 이미 있을 가능성
- 단계 분리(validate → execute) 가능 여부
```

### critic (컨텍스트 0, Phase 1·2 제안만 input)

```
[fresh context — diff는 모름, 제안 목록만 본다]
[제안 목록]
<Phase 1·2에서 나온 리뷰 코멘트 N개>

[과제]
각 제안에 대해 adversarial 반박:
- 과잉 추상화 / 미래 시점 가정 / YAGNI 위반
- 트레이드오프 누락 (이 제안을 적용하면 다른 곳이 나빠지지 않는가)
- 단순 개인 취향인지 vs 객관적 개선인지
- 적용 비용 대비 가치 비율
```

## 출력 형식 (메인 세션이 사용자에게 보고)

```
## Python Deep Review 결과

### Phase 1 1차 리뷰 (4-agent)
- code-reviewer: <요약>
- quality-reviewer: <OOP/SOLID 이슈 N개>
- style-reviewer: <네이밍 이슈 N개>
- architect: <상위 리팩토링 제안 N개>

### Phase 3 독립 검증 (fresh context)
- verifier 추가 발견: <N개>
- critic 반박/약점: <N개>

### 최종 권장
- AUTO-FIX (M개): ...
- ASK (K개, 트레이드오프 있음): ...
- 상위 PR 후보 (L개, 별도 PR로 추천): ...

다음 단계 결정해주세요:
  (1) AUTO-FIX 전부 적용
  (2) 선택 적용 (번호 지정)
  (3) 보류 (PR description에만 코멘트로 남김)
```

## 비용 가드 (운영 중 조정 가능)

기본은 모든 `.py` 변경에 풀세트 발동. 비용 체감 시 아래 옵션:

1. **`--light` 강제 활성화**: Phase 1을 code-reviewer + style-reviewer만, Phase 3 critic만
2. **경로 화이트리스트**: 핵심 경로만 풀세트 (예: `services/`, `tasks/`, `graphql/`). admin/utils는 light
3. **diff 크기 기반**: 5줄 미만 → light, 100줄 이상 → 풀세트 강제

운영 1-2주 후 사용 패턴 보고 §4 표 또는 이 skill에서 가드 켜기.

## 자가 점검 (skill 시작 시 메인이 확인)

- [ ] Phase 1 호출 프롬프트에 4가지 관점 prefix 포함됐는가
- [ ] Phase 3 verifier/critic이 fresh context로 호출되는가 (앞선 결과 주입 금지)
- [ ] architect는 READ-ONLY로 호출 (코드 수정 권한 없음)
- [ ] 모든 opus 호출에 `model: "opus"` 명시
- [ ] 보고서에 "상위 PR 후보" 섹션이 분리되어 있는가 (즉시 머지와 구분)

체크 실패 시 호출 보정 후 재실행.

## 트리거 동작

- 글로벌 CLAUDE.md §4 표의 "Python (.py) 파일 변경" 행 → 이 skill로 위임
- §9 파일/언어 기반 표의 `.py` 트리거 → 자동 invoke
- 사용자가 "skill 스킵" / "바로 해줘" 시 생략 가능
- `--quick` 호환: §4 표의 `--quick`은 이 skill을 우회하고 code-reviewer만 호출
