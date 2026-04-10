# Active Context: fix/avro-dlt-error

## Why
- Branch: `fix/avro-dlt-error` (develop 기준)
- Purpose: Avro 직렬화 메시지가 JSON deserializer로 처리되어 DLT 진입하는 버그 수정

## Progress
e477a901f test: Glue KafkaTemplate 빈 주입 및 Avro/JSON 불일치 재현 테스트
e6bd3374d fix: RepaymentEventPublisherAdapter에 @Qualifier("kafkaTemplate") 추가
Stats: 3 files changed, 344 insertions(+)

## Next
- PR 리뷰 후 머지

## Open Questions
- (none)

---
*Last updated: 2026-04-10 11:20*
