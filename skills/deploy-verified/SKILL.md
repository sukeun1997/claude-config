---
name: deploy-verified
description: "배포 후 수정이 실제 아티팩트에 포함되고 라이브에서 실행 중인지 3단계로 검증. Use when user says '/deploy-verified', '/deploy verify', '배포 검증', '검증 배포', 배포 직후 '수정이 안 들어간 것 같다'는 불평."
---

# /deploy-verified — 배포 검증 파이프라인

`deploy.sh` exit 0은 배포 "시도" 성공일 뿐. 수정이 실제 아티팩트에 포함되었고, 라이브 프로세스가 그것을 실행 중인지 **3단계 증거**로 확인하여 "배포됐는데 수정이 없다" 루프(report.html에서 31회 배포 중 반복 식별)를 차단한다.

## When to Apply

- `/deploy-verified` 또는 `/deploy verify` 호출 시
- `scripts/deploy.sh` 실행 직후 (스킬이 자동 체인)
- 사용자가 "배포했는데 수정이 안 된 것 같다"고 보고할 때

## Arguments

- `--signature <string>`: 라이브 로그에서 찾을 고유 시그니처 (미지정 시 최근 커밋 변경 메서드명에서 추정)
- `--log <path>`: 서버 로그 경로 오버라이드 (미지정 시 프로젝트 매핑 사용)
- `--skip-artifact`: 1단계(JAR 바이너리 검사) 생략 (인터프리터 언어용)
- `--tail-seconds <N>`: 라이브 로그 tail 시간 (기본 60초)

## Pipeline (3 Gates)

```
Gate 1: Artifact Inclusion (아티팩트 포함 확인)
  → 빌드 산출물의 타임스탬프 확인 + 수정 시그니처 바이너리 존재 검증
  ↓ PASS
Gate 2: Log Path Discovery (로그 경로 선확인)
  → 서버의 실제 로그 파일 경로 확인 (ls로 검증, 없으면 중단)
  ↓ PASS
Gate 3: Live Signature Grep (라이브 시그니처 grep)
  → tail -F + grep으로 새 코드 실행 증거 포착 (tail-seconds 내)
  ↓ 3개 모두 PASS
→ "배포 검증 성공" 선언
```

모든 Gate는 **증거 인용 필수**: 파일 경로, 타임스탬프, grep 결과 원문. "성공한 것 같습니다" 금지.

## Gate 1: Artifact Inclusion

목적: `deploy.sh`가 예전 JAR을 재배포했거나 빌드 캐시가 꼬여 수정이 아티팩트에 들어가지 않은 경우를 잡는다.

### 프로젝트 타입별 검증 방법

| 아티팩트 | 검증 |
|---|---|
| Spring Boot JAR | `unzip -p <jar> BOOT-INF/classes/<FQCN>.class \| strings \| grep <signature>` |
| TypeScript 번들 | `grep -r <signature> dist/ build/` + 빌드 디렉토리 mtime이 git commit time 이후 |
| iOS/macOS (.ipa/.app) | `strings <binary> \| grep <signature>` |
| Python | `.pyc` 재생성 확인 또는 소스 배포 mtime |
| Godot (.pck) | `strings game.pck \| grep <signature>` (암호화되지 않은 경우) |

### 시그니처 추정 (--signature 미지정 시)

```
git diff HEAD~1 HEAD --name-only
→ 변경 파일 중 소스 파일 찾기
→ 수정된 메서드명/고유 문자열 1개 추출
→ 사용자에게 "시그니처로 '<candidate>' 사용 OK?" 확인 요청
```

### 실패 시
- JAR에 시그니처 없음 → "빌드 캐시 miss. `./gradlew clean build` 후 재배포 필요"
- 빌드 시간 < 커밋 시간 → "이전 JAR이 배포됨. 재빌드 필요"

## Gate 2: Log Path Discovery

목적: 잘못된 로그 파일을 tail하여 "수정 로그가 안 찍혔다"고 오판하는 루프를 차단.

### 프로젝트 로그 경로 매핑 (수근 환경)

| 프로젝트 | 서버 로그 경로 | 연결 방법 |
|---|---|---|
| todo-app (Spring) | **사용자 확인 필요** — 첫 실행 시 저장 | ssh 또는 docker logs |
| building-manager (백엔드) | **사용자 확인 필요** | ssh |
| game-server | **사용자 확인 필요** | ssh |
| Godot 4X 게임 | 로컬 stdout (배포 대상 아님) | - |
| AI News pipeline | 로컬 LaunchAgent 로그 | `~/Library/Logs/` 스캔 |

첫 사용 시 사용자에게 경로를 받아 `~/.claude/skills/deploy-verified/log-paths.json`에 저장 (프로젝트명: 경로).

### 검증
```bash
ssh <server> "ls -la <log_path> && tail -1 <log_path>"
# 파일 없음 → STOP, 경로 재확인 요청
# 최근 수정 시간 > 5분 전 → WARN (로그가 죽었을 가능성)
```

## Gate 3: Live Signature Grep

목적: 아티팩트에 수정이 있고 배포되었어도, 라이브 프로세스가 **구버전을 여전히 실행 중**(restart 누락, blue-green 스위치 실패)일 수 있음. 라이브 로그에서 시그니처를 직접 확인해야 통과.

### 능동 트리거 시도
시그니처를 로그에 찍기 위해 관련 엔드포인트를 호출:
1. Gate 1에서 식별한 변경 파일이 컨트롤러/핸들러면 → 해당 엔드포인트 1회 호출
2. 엔드포인트 매핑 불명 → 사용자에게 "검증용 요청 1회 보내주세요" 안내 후 tail 시작

### Grep 로직
```bash
ssh <server> "timeout ${tail_seconds:-60} tail -F <log_path> | grep -m 1 '<signature>'"
```
- 발견 → PASS, 로그 라인 타임스탬프 인용
- timeout → FAIL, "프로세스가 수정을 실행하지 않음. restart 상태 확인 필요"

## 출력 포맷

```
[Gate 1: Artifact] ✅ PASS
  JAR: build/libs/app.jar (2026-04-18 16:45:12)
  시그니처 발견: 'handleRefundV2' in BOOT-INF/classes/.../RefundController.class

[Gate 2: Log Path] ✅ PASS
  서버: prod-01
  경로: /var/log/app/app.log (최근 수정: 2s 전)

[Gate 3: Live Signature] ✅ PASS
  발견: 2026-04-18 16:47:33.102 INFO ... handleRefundV2 invoked
  (tail 12s 경과)

→ 배포 검증 성공. 수정이 라이브에서 실행 중.
```

실패 시:
```
[Gate 1: Artifact] ❌ FAIL
  JAR 빌드 시간: 2026-04-18 14:20:00
  최근 커밋 시간: 2026-04-18 16:40:00
  → 이전 빌드 배포됨. 다음 조치:
    1. ./gradlew clean build
    2. scripts/deploy.sh 재실행
    3. /deploy-verified 재실행
```

## log-paths.json 스키마

```json
{
  "todo-app": {
    "server": "prod-todo-01",
    "log_path": "/var/log/todo/app.log",
    "connect": "ssh prod-todo-01"
  },
  "building-manager": {
    "server": "prod-bm-01",
    "log_path": "/var/log/pm2/app-out.log",
    "connect": "ssh prod-bm-01"
  }
}
```

첫 배포 검증 시 사용자에게 받아 저장. 이후 재사용.

## 중단 조건

- Gate 1 실패 → Gate 2/3 실행 금지 (아티팩트 자체가 없으면 의미 없음)
- 사용자가 로그 경로 미제공 → Gate 2에서 STOP, 경로 확인 후 재실행 요청
- 시그니처 후보가 너무 일반적(`get`, `set` 등) → 사용자 확인 필수

## Important Rules

1. **3 Gate 모두 PASS만 성공 선언** — "빌드됐고 배포됐다"만으로는 불충분
2. **증거 인용** — 각 Gate마다 명령 원본 출력 인용. "checked OK" 금지
3. **실패 시 구체적 조치** — "다시 해보세요"가 아닌 다음 명령을 제시
4. **로그 경로는 한 번만 묻기** — log-paths.json에 캐시, 변경 시 `--log`로 오버라이드
5. **능동 트리거 우선** — 수동적 tail이 아니라 엔드포인트 호출로 시그니처를 강제로 찍게 함

## Example

```
사용자: scripts/deploy.sh && /deploy-verified --signature handleRefundV2

Gate 1: ./gradlew build 산출물 확인
  ✅ app-1.0.3.jar 포함 'handleRefundV2' (unzip + strings grep)
  ✅ JAR mtime (16:45:12) > commit time (16:40:03)

Gate 2: 로그 경로 확인
  log-paths.json에서 'todo-app' → /var/log/todo/app.log
  ✅ ssh prod-todo-01 ls -la: 2초 전 수정됨

Gate 3: 능동 트리거 + grep
  POST /api/refund → 200
  ✅ tail 3초 만에 발견:
    "2026-04-18 16:47:33.102 INFO RefundController - handleRefundV2 called for orderId=42"

→ 배포 검증 성공 ✅
   - 아티팩트: app-1.0.3.jar @ 16:45:12
   - 라이브 증거: 16:47:33 handleRefundV2 실행 확인
```
