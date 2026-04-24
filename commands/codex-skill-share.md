# Codex Skill Share

Claude skill을 Codex에서도 재사용 가능한 형태로 동기화한다.

## 핵심 판단

- **가능**: yes
- **전제**: 모든 skill이 아니라 **portable skill만**
- **기본 권장 방식**: `copy`
- **실시간 단일 원천 필요 시**: `symlink`

## 왜 전부는 안 되나

다음 요소가 있으면 Codex에서 그대로 동작하지 않을 수 있다.

- `superpowers:*`
- Claude 전용 MCP 명칭
- Claude hook / Plan mode / plugin 가정
- Claude 전용 절대 경로와 권한 모델

즉, **형식은 같아 보여도 실행 표면이 다르다.**

## 사용 방법

### 1. dry-run

```bash
python3 ~/.claude/scripts/sync-codex-skills.py --dry-run
```

### 2. portable skill만 Codex로 복사

```bash
python3 ~/.claude/scripts/sync-codex-skills.py
```

기본 타깃:

```text
~/.codex/skills/omc-shared
```

### 3. symlink 모드

```bash
python3 ~/.claude/scripts/sync-codex-skills.py --mode symlink
```

## 특정 skill만 공유

```bash
python3 ~/.claude/scripts/sync-codex-skills.py \
  --skill arch-diagram \
  --skill haru-infra \
  --skill master-guide
```

## 호환성 판정 방식

스크립트는 기본적으로 아래를 한다.

1. `skills/*/(SKILL.md|skill.md)` 탐색
2. Claude 전용 패턴 탐지
3. portable skill만 선별
4. Codex용으로 `SKILL.md` 이름 정규화
5. `~/.codex/skills/omc-shared/` 아래로 복사 또는 symlink

## 권장 운영

1. source of truth는 `~/.claude/skills`
2. Codex는 `omc-shared/` 아래로만 받아서 충돌 범위 축소
3. shared skill 수정 후에는 dry-run → 실제 sync 순서 유지

## 현재 로컬 상태

- 현재 로컬 스캔 기준 portable skill **21개**가 `~/.codex/skills/omc-shared/`에 동기화됨
- 현재 skip 대상 **6개**
  - `daily-briefing`
  - `feature`
  - `master-guide`
  - `notion-writer`
  - `research-to-notion`
  - `subagent-driven-development`

## 주의

- 호환성 필터는 보수적으로 동작한다. 본문뿐 아니라 references 파일 안의 Claude 전용 패턴도 검사한다.
- sync 결과가 늘 정답은 아니므로, 새로 공유된 skill은 처음 1회 실제 사용 전 간단히 열어보는 것이 안전하다.

$ARGUMENTS
