# MySQL MCP Server Setup

report.html(2026-04-18)이 식별한 마찰 공략:
- 컬럼명 추측 반복 (Bkmemo vs Bkjukyo)
- 로컬 `.env`가 서버 DB를 가리켜 마이그레이션 중복 실행
- SQL 백업 파일로 폴백하는 수동 쿼리

MCP가 해결: Claude가 DESCRIBE/SELECT를 직접 실행 → 컬럼 추측 제거 + 스키마 검증 자동화.

---

## 1) 패키지 선택

| 패키지 | 특징 | 권장 용도 |
|---|---|---|
| `@benborla29/mcp-server-mysql` | Claude Code 최적화, SSH 터널 지원, 쓰기 옵션 | 프로덕션 DB 읽기 + 스테이징 쓰기 |
| `@liangshanli/mcp-server-mysql` | READONLY 모드 환경변수 제어, DDL 지원 | **로컬/개발 DB (권장 시작점)** |

**시작 권장**: `@liangshanli/mcp-server-mysql` + READONLY=true.
잘못된 DB를 가리키는 재현 마찰을 본 적 있으니, 첫 설정은 읽기 전용으로 시작해 실수 블래스트 반경을 0으로 만든다.

---

## 2) 민감 정보 분리

비밀번호는 `.mcp.json`에 직접 쓰지 말고 `.env` 또는 쉘 환경변수로 참조:

```bash
# ~/.zshrc 또는 ~/.env.local (git ignore됨)
export BUJUNGDB_HOST=localhost
export BUJUNGDB_PORT=3306
export BUJUNGDB_USER=readonly_user
export BUJUNGDB_PASSWORD='<비밀번호>'
export BUJUNGDB_DATABASE=bujungdb
```

**로컬/서버 DB 분리 원칙** (리포트의 "중복 실행" 사고 재발 방지):
- `LOCAL_*` 접두사 → 로컬 MySQL
- `PROD_*` 접두사 → 프로덕션 (READONLY 필수)
- 두 개를 동시에 연결하려면 MCP 서버 엔트리를 2개로 분리 (`mysql-local`, `mysql-prod`)

---

## 3) `.mcp.json` 추가 블록 예시

`/Users/sukeun/.claude/.mcp.json`의 `mcpServers`에 추가:

```json
"mysql-local": {
  "command": "npx",
  "args": [
    "-y",
    "@liangshanli/mcp-server-mysql"
  ],
  "env": {
    "MYSQL_HOST": "${LOCAL_DB_HOST}",
    "MYSQL_PORT": "${LOCAL_DB_PORT}",
    "MYSQL_USER": "${LOCAL_DB_USER}",
    "MYSQL_PASSWORD": "${LOCAL_DB_PASSWORD}",
    "MYSQL_DATABASE": "${LOCAL_DB_NAME}",
    "READONLY": "true"
  }
}
```

프로덕션 DB를 추가할 때(읽기 전용 필수):

```json
"mysql-prod": {
  "command": "npx",
  "args": ["-y", "@liangshanli/mcp-server-mysql"],
  "env": {
    "MYSQL_HOST": "${PROD_DB_HOST}",
    "MYSQL_USER": "${PROD_READONLY_USER}",
    "MYSQL_PASSWORD": "${PROD_READONLY_PASSWORD}",
    "MYSQL_DATABASE": "${PROD_DB_NAME}",
    "READONLY": "true"
  }
}
```

---

## 4) 설치 및 검증 체크리스트

```bash
# 1. Claude Code 재시작 전 npm 패키지 미리 설치 (캐시)
npx -y @liangshanli/mcp-server-mysql --version

# 2. 환경변수가 로드되었는지 확인
echo "host=$LOCAL_DB_HOST db=$LOCAL_DB_NAME user=$LOCAL_DB_USER"

# 3. 직접 연결 테스트 (mcp 거치지 않고)
mysql -h "$LOCAL_DB_HOST" -u "$LOCAL_DB_USER" -p"$LOCAL_DB_PASSWORD" \
  -e "SELECT DATABASE(), @@hostname, USER()"

# 4. Claude Code 재시작 후 MCP 목록 확인
# (Claude Code CLI에서) /mcp
```

검증 실패 시 체크 순서:
1. 환경변수 미로드 → 셸 재시작 또는 `source ~/.zshrc`
2. 포트 충돌 → `lsof -i :3306`
3. 호스트 오타 → `.env`에 `host=localhost`인데 VPN 요구되는 DB 호스트 아닌지
4. READONLY 위반 → 업데이트/삭제 쿼리는 차단됨 (의도된 동작)

---

## 5) 규칙 (리포트 마찰 대응)

Claude가 MySQL MCP를 사용할 때 아래 규칙을 준수:

- **스키마 먼저**: 새 테이블에 대해 쿼리 전 `DESCRIBE <table>` 또는 `SHOW COLUMNS FROM <table>` 실행. 컬럼명 가정 금지 (Bkmemo vs Bkjukyo 반복 대응)
- **타겟 확인**: 쓰기 쿼리 전 `SELECT @@hostname, DATABASE()` 출력. 로컬인지 프로덕션인지 확인 후 진행
- **LIMIT 기본**: 탐색 쿼리에 `LIMIT 100` 기본 부여. 수천/수만 레코드 덤프 방지
- **멀티 서버 전환 명시**: `mysql-local`과 `mysql-prod` 사용 시 어느 쪽을 쓰는지 사용자에게 사전 고지

---

## 6) 다음 단계

1. 위 env 변수를 `.env.local` 또는 쉘 rc에 추가 (사용자 직접)
2. `.mcp.json`에 위 블록 추가 (사용자 승인 후 Claude가 편집)
3. Claude Code 재시작
4. 테스트: `mysql-local mcp로 bujungdb의 TBLBANK 스키마 보여줘`
5. 작동 확인되면 기존 `rules/common/verification.md`의 환경 확인 규칙에 MySQL MCP 활용을 추가
