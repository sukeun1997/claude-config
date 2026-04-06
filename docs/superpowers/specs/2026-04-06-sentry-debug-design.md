# sentry-debug 스킬 설계

> Sentry URL/이슈ID → API 데이터 수집 → 원인 분석 → 사용자 승인 → 코드 수정

## 개요

Sentry 이슈를 입력하면 API로 데이터를 수집하고, systematic-debugging 방법론 기반으로 근본 원인을 분석한 뒤, 사용자 승인 후 코드를 수정하는 통합 디버깅 스킬.

## 트리거

- `/sentry-debug <URL>` — Sentry 이슈 URL
- `/sentry-debug <이슈ID>` — 이슈 ID 직접 입력
- `/sentry-debug <URL|ID> --deep` — 최근 10건 이벤트 + 태그 분포 포함

## 전제 조건

- `SENTRY_AUTH_TOKEN`, `SENTRY_BASE_URL` 환경변수 설정 (zshrc)
- cwd가 해당 프로젝트 디렉토리

## 파일 구조

```
~/.claude/skills/sentry-debug/
├── SKILL.md              # 스킬 오케스트레이션
└── scripts/
    └── sentry-fetch.py   # Sentry API 호출 + JSON 파싱
```

---

## 파이프라인

### Phase 1: Sentry 데이터 수집

헬퍼 스크립트 `sentry-fetch.py` 실행.

**기본 모드**:
- `GET /api/0/issues/{id}/` — 이슈 메타
- `GET /api/0/issues/{id}/events/latest/` — 최신 이벤트 (스택트레이스, 태그, 컨텍스트)

**딥 모드** (`--deep`):
- 위 기본 + `GET /api/0/issues/{id}/events/?limit=10` — 최근 10건
- `GET /api/0/issues/{id}/tags/` — 태그 분포

**스크립트 출력 (JSON)**:
```json
{
  "issue": {
    "id": "14497",
    "title": "IllegalStateException: Settlement 데이터를 찾을 수 없습니다",
    "project": "pfct-settlement",
    "count": 266,
    "firstSeen": "2026-03-25T04:40:44Z",
    "lastSeen": "2026-04-06T02:21:44Z",
    "status": "unresolved",
    "substatus": "regressed",
    "level": "error",
    "platform": "java-spring-boot"
  },
  "exception": {
    "type": "IllegalStateException",
    "value": "Settlement 데이터를 찾을 수 없습니다 - repaymentSettleableId: 263205",
    "module": "java.lang"
  },
  "stacktrace": [
    {
      "file": "SettlementTransferRequestWithRepaymentCompletedConsumer.kt",
      "function": "onMessage",
      "line": 50,
      "module": "kr.co.peoplefund.bankingloan.settlement.adapter.inbound.consumer.settlement.SettlementTransferRequestWithRepaymentCompletedConsumer",
      "inApp": true
    }
  ],
  "message": "정산 계산 완료 이벤트 처리 실패 - loanId: 29645, repaymentSettleableId: 263205",
  "tags": {
    "environment": "production",
    "logger": "*.settlement.transfer.SettlementTransferRequestUseCase$Companion"
  },
  "deep": null
}
```

**딥 모드 `deep` 필드**:
```json
{
  "events_count": 10,
  "unique_errors": ["repaymentSettleableId: 263205", "repaymentSettleableId: 263210"],
  "tag_distribution": {
    "environment": {"production": 260, "staging": 6},
    "server_name": {"pod-abc": 130, "pod-def": 136}
  }
}
```

**URL 파싱**: 정규식으로 이슈 ID 추출
- `https://sentry.pfct.io/organizations/.../issues/14497/...` → `14497`

**에러 핸들링**:
- 토큰 미설정 → 에러 메시지 + 설정 안내
- 401 → 토큰 만료/권한 부족 안내
- 404 → 이슈 없음 안내
- 네트워크 에러 → 연결 확인 안내

---

### Phase 2: 원인 분석

systematic-debugging Phase 1 (Root Cause Investigation)을 자동 수행.

1. **in-app 스택트레이스에서 호출 체인 추출**
   - `inApp: true` 프레임만 필터
   - 역순 정렬 (에러 발생 지점 → 호출 원점)

2. **패키지명 → 파일 경로 매핑**
   ```
   kr.co.peoplefund.bankingloan.settlement.domain.settlement.service.SettlementRequestService
   → Glob: **/SettlementRequestService.kt
   → 매칭 안 되면: **/settlement/service/SettlementRequestService.kt 로 좁혀서 재시도
   ```

3. **코드 읽기**
   - 에러 발생 지점: 해당 라인 ±30줄
   - 호출 체인 상위: 최대 3개 파일의 관련 메서드

4. **근본 원인 가설 수립**
   - 예외 타입 + 메시지 + 코드 흐름을 종합 분석
   - "왜 이 데이터가 없는가" 수준의 근본 원인까지 추적

---

### Phase 3: 분석 보고 + 사용자 승인 게이트

아래 형식으로 보고 후 사용자 승인 대기:

```markdown
## Sentry Issue #14497 분석

**이슈**: IllegalStateException: Settlement 데이터를 찾을 수 없습니다
**프로젝트**: pfct-settlement | **발생**: 266회 | **기간**: 3/25 ~ 4/6
**환경**: production | **상태**: regressed

### 호출 체인
Consumer.onMessage (L50)
  → UseCase.handleSettlementCalculationCompleted (L62)
    → Service.createSettlementTransferRequest (L85)
      → Service.findAndValidateSettlements (L167) ✗ 예외 발생

### 근본 원인 가설
[코드 분석 기반 구체적 원인]

### 수정 방향
[구체적 수정 제안 — 파일, 메서드, 변경 내용]

> 이 방향으로 수정을 진행할까요?
```

---

### Phase 4: 코드 수정

사용자 승인 후:

1. **최소 수정 원칙** — systematic-debugging Phase 4 기반, 근본 원인만 수정
2. **빌드 검증** — 프로젝트 빌드 명령 실행
3. **자동 검증 위임** — 변경 규모에 따라 verifier 서브에이전트 (verification.md 프로토콜)

---

## 헬퍼 스크립트 설계: `sentry-fetch.py`

### 인터페이스

```bash
python3 ~/.claude/skills/sentry-debug/scripts/sentry-fetch.py <issue_id_or_url> [--deep]
```

### 동작

1. 입력이 URL이면 정규식으로 이슈 ID 추출
2. 환경변수에서 `SENTRY_AUTH_TOKEN`, `SENTRY_BASE_URL` 읽기
3. API 호출 (urllib, 외부 의존성 없음)
4. 응답에서 필요한 필드만 추출
5. 구조화된 JSON을 stdout으로 출력
6. 에러 시 stderr로 메시지 출력 + exit code 1

### 의존성

- Python 3 stdlib만 사용 (urllib, json, re, sys, os)
- 외부 패키지 불필요

---

## CLAUDE.md 스킬 라우팅 추가

`§9 Auto Skill Routing` 워크플로우 기반 테이블에 추가:

| 트리거 | 스킬 |
|--------|------|
| Sentry URL 또는 이슈 ID 제공 시 | `sentry-debug` |

---

## 범위 외 (이번 구현에서 제외)

- Sentry MCP 서버 (향후 필요 시 승격)
- 프로젝트 경로 자동 매핑 (cwd 기준)
- Sentry 이슈 상태 변경 (resolve 등)
- Slack/알림 연동
