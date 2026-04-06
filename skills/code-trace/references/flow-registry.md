# Flow Registry

등록된 비즈니스 flow와 코드 진입점.

## 등록된 Flow 목록

### 대출실행 (loan-execution)
- **트리거**: `/trace 대출실행`, `/trace loan-execution`
- **진입 함수**: `moneyflow/tasks/loan_executions/execute_loan_one_action_task.py` → `execute_loan_on_action()`
- **핵심 코드 경로**:
  - 검증: `loan_execution/services/validate_loan_execution.py`
  - 스냅샷 생성: `loan_execution/services/get_or_create_loan_execution_snapshot.py`
  - 은행 전문: `moneyflow/tasks/loan_executions/moneyflow_sub_tasks.py`
  - 서브태스크 실행: `moneyflow/tasks/sub_task_runner.py`
  - 원장 생성: `loan_execution/services/get_or_create_loan_and_additional_info.py`
  - 차입자 데이터: `loan_execution/services/init_borrower_moneyflow_data.py`
  - 투자자 데이터: `loan_execution/services/init_investor_moneyflow_data.py`
- **생성 테이블**: LoanExecutionSnapshot, RepaymentScheduleExecutionSnapshot, InvestmentExecution, SettlementScheduleExecutionSnapshot, Loan, LoanBorrowerInfo, LoanReportInfo, LoanManagement, LoanAccount, RepaymentSchedule, RepaymentAccount, LoanInterestRate, InvestmentNote, SettlementSchedule, LoanExtension, LoanMortgage
- **외부 의존**: 전북은행(1000/1100/3000/6000 전문), 금결원(KFTC), pfct-settlement, RMS, CSS, Kafka
- **분기 조건**: disburse_type(자동/수동), 스탁론 여부, 연장 여부, is_test

### 상환 (repayment)
- **트리거**: `/trace 상환`, `/trace repayment`
- **진입 함수**: `moneyflow/services/repayment/repayment_process.py` → `process_repayment()`
- **핵심 코드 경로**:
  - 태스크 진입: `moneyflow/tasks/repayment.py` → `process_repayment_task()`
  - 재계산: `moneyflow/services/repayment/calculator_v2/calculator_v2.py` → `recalculate_repayment_schedules()`
  - Strategy: `moneyflow/services/repayment/calculator_v2/strategies.py` → `RepaymentStrategyFactory`
  - 검증: `moneyflow/services/repayment/validation.py` → `validate_repayment()`
  - 저장: `moneyflow/services/repayment/repayment_process.py` → `save_processed_repayment_schedules()`
  - 정산 생성: `moneyflow/services/settlement/create_repayment_settleable.py` → `create_repayment_settleable()`
  - 정산 동기화: `moneyflow/services/settlement/schedule_sync_after_repayment.py` → `sync_repayment_info_after_repayment()`
  - 채권 상태: `moneyflow/services/repayment/loan_status.py` → `update_loan_after_repayment()`
  - 상환 이체: `moneyflow/tasks/repayment_transfer_task.py` → `process_repayment_transfer_task()`
- **생성/변경 테이블**: RepaymentSchedule, RepaymentSettleable, LegalExpenseRepayment, RepaymentShowcase/Repayment, Loan, LoanOverdue, InterestLimitation, RepaymentDepositable
- **외부 의존**: 전북은행(3200번 전문, 이체), 금결원(KFTC), RMS, Kafka (이벤트 15종), SMS
- **분기 조건**: process_type(회차상환/회차부분상환/중도원리금상환/중도완제상환/매각상환/지정금액상환), EOD 여부, is_deposited, 담보/개인채권, 최종상환 여부
- **상태**: 완성 (2026-04-06 trace 수행)

### 정산 (settlement)
- **트리거**: `/trace 정산`, `/trace settlement`
- **진입 함수**: TBD (trace 미수행)
- **상태**: 미완성

### LPN/양수도 (bond-transfer)
- **트리거**: `/trace LPN`, `/trace 양수도`, `/trace bond-transfer`
- **진입 함수**: `moneyflow/services/bond_transfer/main_process.py` → `run_transfer()`
- **상태**: 미완성 (코드 자체도 TODO 다수)

---

## Flow 추가 방법

새 flow를 trace한 후 아래 형식으로 추가:

```markdown
### {flow명} ({영문명})
- **트리거**: `/trace {키워드1}`, `/trace {키워드2}`
- **진입 함수**: `{파일경로}` → `{함수명}()`
- **핵심 코드 경로**: 
  - {역할}: `{파일경로}`
- **생성 테이블**: {테이블 목록}
- **외부 의존**: {외부 서비스 목록}
- **분기 조건**: {주요 분기}
```
