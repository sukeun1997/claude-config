---
name: haru-infra
description: OCI Always Free + Docker Compose + Nginx 배포 패턴. 인프라/배포 관련 작업 시 자동 적용.
triggers:
  - "배포, deploy 관련 작업"
  - "Docker Compose 설정 변경"
  - "Nginx, SSL, 네트워크 설정"
  - "OCI 서버 관련 작업"
---

# Haru Infrastructure — OCI Always Free 배포 가이드

## 1. 서버 환경

### OCI Always Free Tier
```
인스턴스: ARM A1 (Ampere)
  - 4 OCPU / 24GB RAM
  - Ubuntu (aarch64)
  - 퍼블릭 IP 할당

스토리지:
  - Boot Volume: 50GB (Always Free)
  - Block Volume: 추가 가능 (200GB Free)
```

### 서비스 구성 (Docker Compose)
```
┌─────────────────────────────────────────┐
│  OCI ARM A1 (4 OCPU, 24GB RAM)         │
│                                         │
│  ┌──────────┐   ┌──────────────────┐   │
│  │  Nginx   │──▶│  haru-api:8080   │   │
│  │  :80/443 │   │  (Spring Boot)   │   │
│  └──────────┘   └──────────────────┘   │
│                  ┌──────────────────┐   │
│                  │  PostgreSQL:5432 │   │
│                  └──────────────────┘   │
│                  ┌──────────────────┐   │
│                  │  Redis:6379      │   │
│                  └──────────────────┘   │
└─────────────────────────────────────────┘
```

## 2. Docker Compose 설정

### docker-compose.yml 구조
```yaml
services:
  app:
    image: haru-api:latest
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
    environment:
      - SPRING_PROFILES_ACTIVE=prod
      - SPRING_DATASOURCE_URL=jdbc:postgresql://db:5432/haru
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    volumes:
      - postgres-data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: haru
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]
      interval: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    command: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      retries: 5

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./nginx/ssl:/etc/nginx/ssl
    depends_on:
      - app
```

### 핵심 운영 규칙
```bash
# ✅ .env 변경 후 반드시 up -d (restart는 .env 미반영)
docker compose up -d

# ❌ 금지
docker compose restart  # .env 변경 미반영!
```

## 3. 배포 워크플로우

### scripts/deploy.sh 사용 필수
```bash
# 표준 배포 플로우
./scripts/deploy.sh

# 플로우:
# 1. git pull origin main
# 2. ./gradlew bootJar (ARM aarch64 빌드)
# 3. docker compose build app
# 4. docker compose up -d
# 5. health check (curl localhost:8080/actuator/health)
# 6. 실패 시 이전 이미지로 롤백
```

### Dockerfile (멀티스테이지, ARM)
```dockerfile
# Build stage
FROM gradle:8-jdk21 AS builder
WORKDIR /app
COPY . .
RUN ./gradlew bootJar --no-daemon

# Runtime stage
FROM amazoncorretto:21-alpine
WORKDIR /app
COPY --from=builder /app/build/libs/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

## 4. Nginx 설정

### 리버스 프록시
```nginx
server {
    listen 80;
    server_name api.haru.app;

    # HTTPS 리다이렉트 (SSL 인증서 있을 때)
    # return 301 https://$server_name$request_uri;

    location / {
        proxy_pass http://app:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 큰 파일 업로드 (MS To-Do Import 등)
    client_max_body_size 50M;
}
```

## 5. iptables (보안)

### OCI 인스턴스 방화벽
```bash
# OCI Security List + iptables 모두 설정 필요

# 허용 포트
iptables -A INPUT -p tcp --dport 80 -j ACCEPT    # HTTP
iptables -A INPUT -p tcp --dport 443 -j ACCEPT   # HTTPS
iptables -A INPUT -p tcp --dport 22 -j ACCEPT    # SSH

# 내부 포트는 외부 차단 (Docker 내부 통신만)
# 5432(PostgreSQL), 6379(Redis), 8080(Spring) → 외부 노출 금지
```

## 6. 모니터링 & 유지보수

### 헬스체크
```bash
# 앱 상태
curl -s localhost:8080/actuator/health | jq .

# Docker 상태
docker compose ps
docker compose logs --tail=50 app

# 디스크 사용량 (50GB 제한)
df -h /
docker system df
```

### 로그 관리
```bash
# 로그 로테이션 (디스크 절약)
docker compose logs --tail=1000 app > /tmp/app-$(date +%Y%m%d).log

# 오래된 이미지 정리
docker image prune -f
```

### 리소스 모니터링
```bash
# 메모리 (24GB 중 사용량)
free -h
docker stats --no-stream

# CPU (4 OCPU)
top -bn1 | head -5
```

## 적용 시점
- 배포 관련 작업 시 이 가이드 참조
- Docker Compose 변경 시 운영 규칙 확인
- 새 서비스 추가 시 아키텍처 다이어그램 업데이트
