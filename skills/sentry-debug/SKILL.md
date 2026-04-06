---
name: sentry-debug
description: "Sentry 이슈 URL/ID → API 데이터 수집 → 원인 분석 → 사용자 승인 → 코드 수정. Use when user says '/sentry-debug', 'sentry 분석', 'sentry 디버깅', 'sentry 이슈 분석', or provides a Sentry issue URL."
---

# sentry-debug — Sentry 이슈 기반 통합 디버깅

Sentry 이슈를 입력하면 API로 데이터를 수집하고, systematic-debugging 방법론 기반으로
근본 원인을 분석한 뒤, 사용자 승인 후 코드를 수정한다.

## Arguments

- `<URL|이슈ID>` (required): Sentry 이슈 URL 또는 숫자 ID
- `--deep`: 최근 10건 이벤트 + 태그 분포 포함 분석

## 전제 조건

- `SENTRY_AUTH_TOKEN`, `SENTRY_BASE_URL` 환경변수 (zshrc)
- cwd가 해당 프로젝트 디렉토리

## Pipeline

### Phase 1: Sentry 데이터 수집

Bash로 헬퍼 스크립트를 실행하여 Sentry API 데이터를 수집한다.

```bash
source ~/.zshrc && python3 ~/.claude/skills/sentry-debug/scripts/sentry-fetch.py $ARGUMENTS
```

- 스크립트가 exit code 1을 반환하면 stderr 메시지를 사용자에게 전달하고 중단
- 성공 시 JSON 출력을 파싱하여 이후 Phase에서 사용

### Phase 2: 원인 분석

systematic-debugging Phase 1 (Root Cause Investigation)을 자동 수행한다.

1. **호출 체인 추출**: `stacktrace` 배열에서 in-app 프레임을 역순으로 정렬 (에러 발생 지점 → 호출 원점)

2. **파일 탐색**: 스택트레이스의 `module` 필드에서 클래스명을 추출하여 cwd에서 Glob 탐색
   - 1차: `**/{ClassName}.kt` (또는 `.java`)
   - 매칭 실패 시: module의 마지막 2-3 세그먼트로 `**/{segment}/{ClassName}.kt`

3. **코드 읽기**:
   - 에러 발생 지점(스택트레이스 최상단): 해당 라인 ±30줄 Read
   - 호출 체인 상위: 최대 3개 파일의 관련 메서드 Read

4. **근본 원인 가설 수립**:
   - 예외 타입 + 메시지 + 코드 흐름을 종합 분석
   - "왜 이 데이터가 없는가" / "왜 이 상태가 발생하는가" 수준까지 추적
   - `--deep` 모드에서 태그 분포가 있으면 환경/서버별 패턴도 분석

### Phase 3: 분석 보고 + 사용자 승인 게이트

아래 형식으로 보고 후 사용자 승인을 대기한다.

```
## Sentry Issue #{id} 분석

**이슈**: {exception.type}: {exception.value}
**프로젝트**: {issue.project} | **발생**: {issue.count}회 | **기간**: {firstSeen} ~ {lastSeen}
**환경**: {tags.environment} | **상태**: {issue.status} ({issue.substatus})

### 호출 체인
{스택트레이스를 들여쓰기로 표현, 에러 지점에 ✗ 표시}

### 근본 원인 가설
{코드 분석 기반 구체적 원인}

### 수정 방향
{파일, 메서드, 변경 내용을 구체적으로 제시}

> 이 방향으로 수정을 진행할까요?
```

사용자가 승인하면 Phase 4로 진행. 거부하면 피드백을 반영하여 Phase 2를 재수행하거나 중단.

### Phase 4: 코드 수정

1. **최소 수정 원칙**: systematic-debugging Phase 4 기반, 근본 원인만 수정. "while I'm here" 개선 금지.

2. **빌드 검증**: 프로젝트의 빌드 명령을 실행하여 컴파일 확인
   - Kotlin/Spring: `./gradlew :<module>:compileKotlin`
   - 빌드 명령이 불명확하면 사용자에게 확인

3. **자동 검증 위임**: 변경 규모에 따라 verification.md 프로토콜 적용
   - 소규모 (≤2파일): compileKotlin만
   - 중규모 (3-5파일): 빌드 + 변경 모듈 테스트
   - 대규모 (6+파일): 빌드 + 테스트 + code-reviewer

$ARGUMENTS
