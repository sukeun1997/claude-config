---
name: haru-todo
description: Use when user asks to add tasks/todos to the Haru Todo App, or says /haru-todo. Triggers on "todo앱", "하루앱", "할일 추가", "프메에 넣어", "리스트에 추가".
---

# Haru Todo App - 할일 추가

Haru Todo App(OCI 서버)의 특정 리스트에 할일 항목을 추가한다.

## Quick Reference

**접속**: `ssh -i ~/.ssh/id_ed25519 ubuntu@158.179.165.211`
**DB**: `docker exec haru-db psql -U haru -d harudb`
**User ID**: `f476a20a-8bc9-40b3-b644-f89babcc04dc`

### 리스트 목록

| 이름 | ID |
|------|-----|
| 개발 | `391c2bfa-31d0-4079-b712-18b45ff22352` |
| 공부 | `4b43a576-307e-441c-9bc3-4ad7b4c5b132` |
| 업무 | `606b5862-472c-45dd-aba0-35e6e3baba99` |
| 클로드 | `9d38cd6d-dd76-4550-9acb-7b6f011a6d57` |
| 투두앱 | `21dc075c-b877-418f-a94a-efb616b43fe1` |
| 프메 | `b4fa72e9-34c9-4b49-a756-ef67173ed059` |

### 우선순위 / 상태

- **priority**: `NONE` (기본) | `LOW` | `MEDIUM` | `HIGH` | `URGENT`
- **status**: `TODO` (기본) | `DONE`

## 사용법

### 1. 사용자가 리스트를 지정한 경우

리스트 이름으로 위 테이블에서 ID를 매칭한다. 새 리스트면 먼저 리스트 조회:

```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@158.179.165.211 "docker exec haru-db psql -U haru -d harudb -c \"SELECT id, name FROM todo_list ORDER BY name;\""
```

### 2. 할일 추가 (INSERT)

```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@158.179.165.211 "docker exec haru-db psql -U haru -d harudb -c \"INSERT INTO todo_item (id, user_id, list_id, title, memo, status, priority, created_at, updated_at) VALUES (gen_random_uuid(), 'f476a20a-8bc9-40b3-b644-f89babcc04dc', '{LIST_ID}', '{TITLE}', '{MEMO}', 'TODO', '{PRIORITY}', now(), now());\""
```

**여러 항목 한번에**:

```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@158.179.165.211 "docker exec haru-db psql -U haru -d harudb <<'EOSQL'
INSERT INTO todo_item (id, user_id, list_id, title, memo, status, priority, created_at, updated_at) VALUES
(gen_random_uuid(), 'f476a20a-8bc9-40b3-b644-f89babcc04dc', '{LIST_ID}', '제목1', '메모1', 'TODO', 'MEDIUM', now(), now()),
(gen_random_uuid(), 'f476a20a-8bc9-40b3-b644-f89babcc04dc', '{LIST_ID}', '제목2', '메모2', 'TODO', 'HIGH', now(), now());
EOSQL"
```

### 3. 검증

```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@158.179.165.211 "docker exec haru-db psql -U haru -d harudb -c \"SELECT title, priority, status FROM todo_item WHERE list_id = '{LIST_ID}' AND status = 'TODO' ORDER BY created_at DESC LIMIT 10;\""
```

## 우선순위 판단 기준

사용자가 명시하지 않으면 내용으로 판단:

| 키워드 | 우선순위 |
|--------|---------|
| 긴급, 즉시, 핫픽스, 장애 | `URGENT` |
| 중요, 필수, Java 수정 필요 | `HIGH` |
| 일반 작업, 개선, 추가 | `MEDIUM` |
| 나중에, 여유, 확인, 정리 | `LOW` |
| 불명확 | `NONE` |

## 주의사항

- SQL 내 작은따옴표는 `''`로 이스케이프
- title 최대 500자, memo는 text (무제한)
- list_id 미지정 시 NULL 가능 (Inbox로 분류됨)
- 리스트 목록이 변경되었을 수 있으므로, 새 리스트명이면 DB 조회 먼저
