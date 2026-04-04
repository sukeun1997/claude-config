---
name: evaluation-calibration-pattern
description: "코드 리뷰/QA 에이전트의 평가 품질을 높이기 위한 Few-shot Calibration 패턴. /review 스킬 개선 시 참조."
type: reference
---

# Few-shot Evaluation Calibration Pattern

**출처**: Anthropic "Harness Design for Long-Running Application Development" (2026)

## 핵심 인사이트

1. **자체 평가의 한계**: 모델에게 자기 작업을 평가하라고 하면 "자신감 넘치게 칭찬"하는 경향. 이슈를 발견해도 "대수롭지 않다고 넘어감"
2. **Few-shot 점수 분해**: 평가자에게 점수 기준 + 상세 점수 분해 예시를 제공하면 iteration 간 평가 drift 감소
3. **반복적 프롬프트 튜닝**: 로그 분석 기반으로 evaluator 프롬프트를 반복 개선해야 인간 기준과 정렬됨

## 적용 방법 (향후 /review 개선 시)

- review 스킬에 "좋은 리뷰 예시" vs "나쁜 리뷰 예시" 추가
- 각 severity 등급(CRITICAL/HIGH/MEDIUM/LOW)에 대한 구체적 사례 포함
- 리뷰어가 이슈를 축소 해석하지 않도록 "skeptical by default" 프롬프트 톤 설정
