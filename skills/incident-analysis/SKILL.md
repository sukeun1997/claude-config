---
name: incident-analysis
description: "Incident/RCA report workflow. Use when the user asks for incident analysis, RCA, root-cause summary, 장애 분석, 원인 분석, an end-to-end flow and cause report, or wants a Slack/report-ready explanation before or after a fix."
---

# Incident Analysis

Use this skill to turn a symptom, outage, bug, or confusing production behavior
into a grounded RCA-style report:

```text
흐름 -> 원인 -> 분석 -> 해결방법 -> 검증방법 -> 남은 리스크
```

The goal is not to win a diagnosis debate. The goal is to make the incident
understandable enough that the next action is obvious and verifiable.

## When To Apply

- `/incident-analysis <증상>` or typo alias `/incdient-analysis <증상>`
- `incident-analysis`, `incdient-analysis`, `RCA`, `root cause`, `장애 분석`, `원인 분석`
- The user asks for `흐름 -> 원인 -> 분석 -> 해결방법`
- The user wants a Slack-ready or report-ready explanation of what happened
- The user has logs, stack traces, DB rows, dashboards, Sentry links, or runtime
  observations and wants them reconciled into one explanation
- A previous fix missed the real cause and the user wants diagnosis before
  another change

## Related Skills

- Use `sentry-flow-rca` first for a read-only end-to-end Sentry RCA. Use
  `sentry-debug` when the user also wants a diagnosis-to-fix workflow.
- Use `code-trace` first when the main missing piece is a code-level business
  flow walkthrough.
- Use `domain-modeling-gate` when the cause or fix depends on ambiguous business
  language, state ownership, or an invariant.
- Use `deploy-verified` after a production deployment when the question is
  whether the fix actually reached and works on the live artifact.

## Operating Contract

- Default to read-only evidence gathering and report generation.
- Do not edit code unless the user explicitly asks for implementation or fix.
- Separate observed facts from inference.
- Prefer concrete file paths, function names, SQL/table names, timestamps, logs,
  release identifiers, commit SHAs, request IDs, and exact status/error strings.
- If repo code conflicts with runtime evidence, show both. Treat current runtime
  evidence as authoritative for the active incident until reconciled.
- Do not collapse multi-stage latency or state transitions into one vague cause.
  Split queue time, external dependency time, application processing time, and
  user-facing timeout window when those stages exist.
- For DB, migration, Kafka/event, auth, security, or deployment incidents, apply
  the relevant safety gates before recommending or executing a fix.

## Workflow

### 1. Incident Frame

Capture only what is needed to start. If some fields are missing, proceed with
best effort and mark them as unknown.

- Symptom: what the user/system observed
- Impact: affected users, workflow, money movement, data, or availability
- Time window: first seen, latest seen, release/deploy/commit if known
- Evidence inputs: logs, stack trace, DB rows, screenshots, dashboards, Sentry,
  Slack messages, user-provided runtime observations
- Requested output: internal RCA, Slack summary, fix plan, or handoff note

### 2. Flow Reconstruction

Reconstruct the smallest end-to-end path that explains the symptom.

- Entry point: request, job, consumer, cron, task, UI action, or external event
- Internal path: service/function/task sequence with file references when code
  is inspected
- State changes: DB table/field changes, status transitions, cache keys, queue
  messages, offsets, external calls
- Timing model: split each stage when time matters
- Failure point: where the observed bad state/error first appears

### 3. Cause Analysis

Rank plausible causes instead of flattening them.
When evidence is broad or disputed, form hypotheses from disjoint evidence lanes
first: logs/runtime, code path, DB/data state, configuration, external
dependency, and recent change history. Then refute the leading hypothesis before
recommending a fix.

For each cause:

- Claim: the specific mechanism that produced the symptom
- Evidence for: concrete facts supporting it
- Evidence against: facts that weaken or constrain it
- Confidence: High / Medium / Low
- Blast radius: what else this cause could affect
- Discriminator: the next check that would confirm or reject it
- Refuter result: the strongest contradictory evidence found, or why none was
  available

### 4. Solution Options

Offer minimal, reversible remedies tied to the cause.

- Immediate mitigation: what reduces impact now
- Root-cause fix: smallest code/config/data/process change that removes the
  mechanism
- Regression coverage: unit, integration, e2e, SQL probe, synthetic check, or
  monitoring assertion that would fail before the fix
- Operational follow-up: alerting, dashboard, runbook, rollback, communication
- Rejected option: tempting workaround and why it is weaker or risky

### 5. Verification

Define proof before claiming resolution.

- Local proof: tests, reproduction, log replay, code path check
- Runtime proof: deployment artifact, dashboard, DB query, queue depth, Sentry
  trend, API response, job success, external dependency response
- Stop condition: exact observation that means the incident is resolved
- Remaining risk: what still is not proven

## Senior / CTO Incident Lens

In addition to the immediate bug, check:

1. Why existing controls did not prevent or detect the failure.
2. Whether retry, concurrency, partial failure, or a second entry point can
   create the same invalid state.
3. Whether operators can diagnose and recover without code archaeology.
4. Whether ownership is clear across services and teams.
5. Whether the fix preserves audit/history, compatibility, rollout, and
   rollback requirements.

Keep systemic observations separate from the minimum incident fix.

## Output Contract

Use Korean by default when the user wrote in Korean. Keep exact technical nouns
in their original spelling.

```markdown
## 흐름
- [entrypoint] -> [service/task] -> [DB/external system] -> [failure point]
- 시간/상태가 중요하면 단계별로 분리:
  - T1: ...
  - T2: ...

## 원인
1. [원인 후보] - 신뢰도: High/Medium/Low
   - 직접 근거:
   - 반대/제한 근거:
   - 반박 검증:
   - 다음 확인:

## 분석
- 왜 이 증상이 이 원인에서 나오는지:
- 영향 범위:
- 코드/DB/런타임 증거의 일치 여부:
- 통제·탐지·복구가 실패한 이유:
- 아직 모르는 것:

## 해결방법
- 즉시 완화:
- 근본 수정:
- 회귀 테스트/검증:
- 피해야 할 우회:

## 검증방법
- 로컬:
- 런타임/운영:
- 완료 조건:

## 남은 리스크
- ...
```

For Slack-ready output, compress the same content:

```markdown
[요약]
- 현상:
- 원인:
- 조치:
- 검증:
- 남은 리스크:
```

## Quality Bar

A good incident-analysis response:

- starts with the business/user-visible flow, not only code internals
- distinguishes direct evidence, inference, and unknowns
- names the exact stage where the failure enters the flow
- distinguishes the trigger, root mechanism, and control gap
- includes a minimal root-cause fix, not only symptom masking
- defines verification that can be run after the fix
- is concise enough to paste into Slack, but grounded enough to defend
