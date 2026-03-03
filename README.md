# Claude Code Config

Claude Code 글로벌 설정을 Git으로 관리하여 여러 머신에서 동일한 환경을 유지합니다.

## 구조

```
~/.claude/
├── CLAUDE.md              # 글로벌 지시사항 (모든 프로젝트 공통)
├── agents/                # 커스텀 서브에이전트 정의
├── commands/              # 슬래시 커맨드 (/bs, /update-pr 등)
├── rules/                 # 글로벌 룰 (coding-style, security 등)
│   ├── common/
│   └── typescript/
├── hooks/                 # 메모리 시스템 등 자동화 훅
├── skills/                # 커스텀 스킬
├── plugins/               # 플러그인 설정 (설치 목록)
├── hud/                   # HUD 설정
├── settings.json          # 공통 설정
├── settings.local.json    # 머신별 오버라이드 (.gitignore)
└── templates/             # 템플릿 파일
```

## 새 머신에서 셋업

```bash
# 1. 기존 ~/.claude/ 백업
mv ~/.claude ~/.claude.bak

# 2. 클론
git clone https://github.com/sukeun8/claude-config.git ~/.claude

# 3. 백업에서 로컬 데이터 복원 (필요한 경우)
cp -r ~/.claude.bak/projects ~/.claude/
cp ~/.claude.bak/history.jsonl ~/.claude/
cp ~/.claude.bak/settings.local.json ~/.claude/  # 머신별 설정 있으면

# 4. Claude Code 실행 → 플러그인 자동 재설치됨
```

## 일상 동기화

```bash
# 설정 변경 후 push
cd ~/.claude && git add -A && git commit -m "feat: ..." && git push

# 다른 머신에서 pull
cd ~/.claude && git pull
```

## Git 추적 대상

| 추적 (동기화) | 제외 (머신 로컬) |
|---|---|
| `CLAUDE.md` | `debug/`, `file-history/` |
| `agents/`, `commands/`, `rules/` | `history.jsonl`, `sessions/` |
| `hooks/`, `skills/` | `projects/`, `cache/`, `paste-cache/` |
| `settings.json`, `hud/` | `telemetry/`, `usage-data/` |
| `plugins/*.json` (설치 목록) | `plugins/marketplaces/`, `plugins/cache/` |
| `templates/` | `backups/`, `daily/`, `agent-memory/` |

## 머신별 설정 분리

`settings.json`은 공통, `settings.local.json`은 머신별 오버라이드용입니다.

```jsonc
// settings.local.json (예시 - .gitignore 대상)
{
  "mcpServers": {
    "local-only-server": { "command": "/opt/homebrew/bin/my-tool" }
  }
}
```

## 주의사항

- symlink된 skills (`tutor`, `find-skills` 등)는 타겟 경로가 양쪽 머신에서 동일해야 합니다
- 플러그인 바이너리는 추적하지 않으며, Claude Code 실행 시 `installed_plugins.json` 기반으로 자동 재설치됩니다
