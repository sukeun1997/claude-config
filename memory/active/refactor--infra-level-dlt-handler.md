# Active Context: refactor/infra-level-dlt-handler

## Why

- Branch: `refactor/infra-level-dlt-handler` (25 commits ahead of develop)
- Purpose: infra level dlt handler

## Progress
8554c466 chore: log4j2 설정을 banking-loan 표준으로 통일
324ec4ec fix: client-test에서 MockServer 의존성 분리하여 SLF4J 충돌 해결
dc6f9532 refactor: Glue consumer DLT 처리를 Composition 패턴으로 변경
79298b83 chore: Kafka 포트 29092 복원, ConsumerDeduplicationIdBuilder KDoc 추가, 불필요한 주석 제거
033861c6 refactor: 미사용 ConsumerDeduplicationConstants.buildGlueConsumerDeduplicationId 제거
e126e556 refactor: Glue dedup ID의 vararg Any를 명시적 타입 파라미터로 변경
0716105d refactor: Glue consumer dedup ID를 빌더 패턴으로 표준화
485b7404 fix: client-test를 testImplementation으로 변경하여 SLF4J 충돌 해결
1cd70f44 refactor: @ConditionalOnClass 및 불필요한 retryTopicSuffix/dltTopicSuffix 제거
78916beb chore: 불필요한 @ConditionalOnClass 관련 주석 제거

### Changed Files
```
app/internal-api-app/build.gradle.kts
app/internal-api-app/src/main/kotlin/kr/co/peoplefund/bankingreport/banking/consumer/OverdueEventConsumer.kt
app/internal-api-app/src/main/kotlin/kr/co/peoplefund/bankingreport/banking/consumer/OverdueGlueEventConsumer.kt
app/internal-api-app/src/main/kotlin/kr/co/peoplefund/bankingreport/config/KafkaConsumerFactoryConfig.kt
app/internal-api-app/src/main/kotlin/kr/co/peoplefund/bankingreport/kcreditreport/consumer/OverdueStartBorrowerDetailChangeConsumer.kt
app/internal-api-app/src/main/kotlin/kr/co/peoplefund/bankingreport/kcreditreport/consumer/OverdueStartBorrowerDetailChangeGlueConsumer.kt
app/internal-api-app/src/main/resources/log4j2-local.yml
app/internal-api-app/src/main/resources/log4j2.yml
app/internal-api-app/src/test/kotlin/kr/co/peoplefund/bankingreport/banking/consumer/OverdueGlueConsumerE2eTest.kt
app/internal-api-app/src/test/kotlin/kr/co/peoplefund/bankingreport/banking/consumer/OverdueGlueEventConsumerDltIntegrationTest.kt
app/internal-api-app/src/test/kotlin/kr/co/peoplefund/bankingreport/banking/consumer/OverdueGlueEventConsumerTest.kt
app/internal-api-app/src/test/kotlin/kr/co/peoplefund/bankingreport/kcreditreport/consumer/OverdueStartBorrowerDetailChangeGlueConsumerTest.kt
app/internal-api-app/src/test/resources/application.yml
app/internal-api-app/src/test/resources/log4j2.yml
app/scheduler-app/src/main/resources/log4j2-local.yml
app/scheduler-app/src/main/resources/log4j2.yml
app/scheduler-app/src/test/resources/application.yml
build.gradle.kts
client/client-test/build.gradle.kts
client/dove-client/build.gradle.kts
```
Stats:  31 files changed, 1512 insertions(+), 70 deletions(-)

## Next
- (auto-generated — update with current next steps)

## Open Questions
- (none yet)

---
*Auto-generated on 2026-03-31 18:19. Update manually or via `/clear`.*
