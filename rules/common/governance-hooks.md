# Governance as Code

"차단이 아닌 자동 교정" — Toss "Harness" 패턴 적용.

## frozen.yml vs governance.yml

| 파일 | 역할 | 동작 | 사용 시점 |
|------|------|------|-----------|
| `frozen.yml` | **수정 차단** | 파일 수정 시 에러 + 사용자 승인 필요 | build.gradle.kts 등 절대 보호 |
| `governance.yml` | **변경 감시** | 파일 수정 시 경고 + 관련 slash command 추천 | Avro, Consumer, Migration 등 주의 필요 파일 |

## governance.yml 구조

```yaml
rules:
  - pattern: "*.avsc"
    message: "Avro 스키마 변경 감지"
    recommend: "/avro-plan"
    severity: warn

  - pattern: "*Consumer*.kt"
    message: "Kafka Consumer 변경 감지"
    recommend: "토픽/DLT/멱등성 확인 필요"
    severity: warn
```

## Hook 우선순위

PostToolUse Hook 실행 순서:
1. `continuous-learning` (관찰/학습)
2. `memory-post-tool.py` (메모리 기록)
3. `memory-conversation-summarizer.py` (대화 요약)
4. `context-cost-monitor.sh` (비용 모니터링)
5. **`governance-guard.sh`** (변경 감시 — 경고 출력)
6. **`skill-usage-tracker.sh`** (스킬 사용 추적)

## 원칙

- **경고는 하되 차단하지 않는다**: governance.yml 매칭은 stderr로 경고만 출력
- **행동을 추천한다**: 관련 slash command나 확인사항을 안내
- **프로젝트별 독립**: 각 프로젝트가 자체 governance.yml을 가질 수 있음
- **점진적 확장**: 규칙은 실제 실수 사례에서 추출하여 추가
