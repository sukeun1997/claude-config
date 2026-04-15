# Scoring Guide — 프로필 기반 관련도 판단

## Phase 0: 프로필 로드

1. Read: `~/.claude/memory/topics/user-profile.md`
2. 키워드 추출:
   - 주력 스택 (예: Kotlin, Spring Boot, Gradle)
   - 인프라 (예: Kafka, Redis, MySQL)
   - 관심사 (예: EDA, DDD, 헥사고날, 대규모 트래픽)
   - 도구 (예: Claude Code, IntelliJ IDEA)
3. 파일 없으면 기본값: `["Kotlin", "Spring Boot", "Claude Code"]`

## Phase 2: 스코어링

수집된 뉴스 항목 전체를 한번에 판단한다.

### 프롬프트

```
다음은 사용자의 기술 프로필이다:
{profile_keywords}

아래 뉴스 항목 각각에 대해 이 사용자와의 관련도를 판단하라.

각 항목마다:
1. score (0-100): 관련도 점수
2. tier: HIGH (≥80) | MED (50-79) | LOW (<50)
3. action: 구체적 적용 방법 1-2문장
4. category: ai-tools | backend | infra | community

뉴스 항목:
{items}
```

### 스코어 기준 (기본 관련도)

- 80-100: 현재 사용 중인 기술 직접 관련 (릴리스, 보안 패치, 신기능)
- 60-79: 관심 분야 관련 (EDA, DDD, 아키텍처 패턴)
- 40-59: 일반적 참고 (업계 동향, 타 기업 사례)
- 0-39: 거의 무관

### 신선도 보정 (Freshness Penalty)

게시일이 파악된 항목에 대해:
- **24시간 이내**: 보정 없음 (최신)
- **24-48시간**: score × 0.9 (10% 감점)
- **48-72시간**: score × 0.7 (30% 감점)
- **72시간 초과**: score × 0.5 (50% 감점)
- **날짜 불명**: 보정 없음 (블로그 등 공식 소스는 날짜 무관하게 유효)

### 인기도 가중치 (Popularity Boost)

`popularity` 필드가 있는 항목에 보너스:
- **HN points**: 100+ → +10, 300+ → +20, 500+ → +30
- **GitHub stars today**: 100+ → +10, 500+ → +20, 1000+ → +30
- **Dev.to reactions**: 50+ → +5, 100+ → +10, 200+ → +15
- **인기도 없음** (블로그 공식 소스): 가중치 없음 (관련도만 판단)

최종 score = min(100, base_score × freshness_multiplier + popularity_boost)

### 적용 방법 작성 규칙

- ✗ 추상적: "검토해보세요", "알아두면 좋습니다"
- ✓ 구체적: "`build.gradle.kts`에 `spring-boot-starter-opentelemetry` 추가"
- ✓ 워크플로우 연결: "기존 Telegram MCP와 Channels 비교 테스트"
- ✓ 명령어 포함: "`claude --channels plugin:telegram@claude-plugins-official`로 시작"

### 필터링

- quick: HIGH + MED만 유지, score 내림차순, 최대 10개
- deep: 전체 유지, score 내림차순, 최대 20개
