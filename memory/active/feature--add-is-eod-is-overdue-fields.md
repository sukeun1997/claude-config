# Active Context: feature/add-is-eod-is-overdue-fields

## Why

- Branch: `feature/add-is-eod-is-overdue-fields` (146 commits ahead of develop)
- Purpose: add is eod is overdue fields

## Progress
9a2a1a670 EodInvoiceCreated 이벤트 결정을 도메인 레이어로 이동 (RepaymentInvoice.toEodInvoiceCreatedEvent)
a6123719e 테스트 수정: EodStateUseCase 리네이밍, EodInvoiceCreated/EodStarted 반영
37a38d27e EodRevivalPort/UseCase → EodStatePort/UseCase 리네이밍, startEod 구현, EodInvoiceCreated 소비자 추가
4d47ba8ad EodRepaymentInvoice.toCreatedEvent() 추가, InvoiceCreateUseCase에서 EodInvoiceCreated 발행
6de7f70b7 EodState sealed class 도입, EodRevivalResult 대체, EodStarted/EodInvoiceCreated 이벤트 인프라 추가
519eb74af Loan.startEod() 메서드 추가
2fda8feb1 InvoiceCreateUseCase 이벤트 발행을 publishAll로 통합
ed35ce8ca OverdueEndedEvent 필드 간 줄바꿈 추가
6114e8bbb 마이그레이션: is_overdue, is_eod 불필요한 인덱스 제거
31348e26b 테스트 수정: LoanRepository mock 추가, overdueHistory resolve 비동기 전환 반영

### Changed Files
```
.dockerignore
.github/workflows/pull-request-create-automation-on-push.yml
client/cert-client/src/main/kotlin/kr/co/peoplefund/bankingloan/client/cert/PfCertClient.kt
client/slack-client/src/main/kotlin/kr/co/peoplefund/bankingloan/client/slack/SparrowClient.kt
cms/src/main/kotlin/kr/co/peoplefund/bankingloan/cms/adapter/inbound/api/exception/ControllerExceptionHandler.kt
cms/src/main/kotlin/kr/co/peoplefund/bankingloan/cms/domain/presentation/CmsEb13RegistrationFacadeService.kt
cms/src/main/kotlin/kr/co/peoplefund/bankingloan/cms/domain/service/CmsAggregationService.kt
cms/src/main/kotlin/kr/co/peoplefund/bankingloan/cms/domain/service/CmsEb13RegisterDetailService.kt
cms/src/main/kotlin/kr/co/peoplefund/bankingloan/cms/domain/service/CmsRequestService.kt
cms/src/main/kotlin/kr/co/peoplefund/bankingloan/cms/usecase/batch/CmsBatchFacade.kt
cms/src/test/kotlin/kr/co/peoplefund/bankingloan/cms/adapter/inbound/api/controller/impl/CmsControllerImplTest.kt
cms/src/test/kotlin/kr/co/peoplefund/bankingloan/cms/domain/service/CmsAggregationServiceTest.kt
cms/src/test/kotlin/kr/co/peoplefund/bankingloan/cms/domain/service/CmsEb13RegisterDetailServiceTest.kt
common/core/build.gradle.kts
common/core/src/main/kotlin/kr/co/peoplefund/domain/exception/BankingError.kt
common/core/src/main/kotlin/kr/co/peoplefund/domain/exception/BankingLoanError.kt
common/core/src/main/kotlin/kr/co/peoplefund/domain/exception/BaseException.kt
common/core/src/main/kotlin/kr/co/peoplefund/domain/exception/common/DataDuplicatedConflictException.kt
common/core/src/main/kotlin/kr/co/peoplefund/domain/exception/common/InternalServerException.kt
common/core/src/main/kotlin/kr/co/peoplefund/domain/exception/common/InvalidParameterException.kt
```
Stats:  235 files changed, 6088 insertions(+), 3770 deletions(-)

## Next
- (auto-generated — update with current next steps)

## Open Questions
- (none yet)

---
*Auto-generated on 2026-03-31 18:21. Update manually or via `/clear`.*
