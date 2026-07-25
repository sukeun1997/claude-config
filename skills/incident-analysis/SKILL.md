---
name: incident-analysis
description: "Incident/RCA report workflow. Use when the user asks for incident analysis, RCA, root-cause summary, 장애 분석, 원인 분석, an end-to-end flow and cause report, or wants a Slack/report-ready explanation before or after a fix."
---

# Incident Analysis

Turn a symptom, outage, bug, or confusing production behavior into a grounded
RCA-style report:

```text
흐름 -> 원인 -> 분석 -> 해결방법 -> 검증방법 -> 남은 리스크
```

The goal is to make the incident understandable enough that the next action is
obvious and verifiable.

## Related Skills

- Use `sentry-flow-rca` first for a read-only end-to-end Sentry RCA. Use
  `sentry-debug` when the user also wants a diagnosis-to-fix workflow.
- Use `code-trace` when the main missing piece is the code-level business flow,
  DB row unit, or cross-service path.
- Use `domain-modeling-gate` when the cause or fix depends on ambiguous business
  language, state ownership, or an invariant.
- Use `deploy-verified` after deployment when the question is whether the fix
  reached and works on the live artifact.

## Operating Contract

- Default to read-only evidence gathering and report generation.
- Do not edit code unless the user asks for implementation or a fix.
- Separate observed facts, inference, and unknowns.
- Prefer concrete file paths, functions, SQL/table names, timestamps, logs,
  releases, commit SHAs, request IDs, and exact status/error strings.
- If code conflicts with runtime evidence, preserve both and treat current
  runtime evidence as authoritative for the active incident until reconciled.
- Do not collapse multi-stage latency or state transitions into one vague cause.
- Apply the relevant DB, message, security, or deployment safety gate before
  recommending or executing a risky fix.

## Workflow

### 1. Frame the Incident

Proceed with best effort when fields are missing and mark them unknown.

- Symptom: what the user/system observed
- Impact: affected users, workflow, money, data, or availability
- Time window: first/latest occurrence and release/deploy context
- Evidence: logs, stack trace, DB rows, dashboard, Sentry, Slack, runtime state
- Requested output: RCA, Slack summary, fix plan, or handoff

### 2. Reconstruct the Flow

Trace the smallest end-to-end path that explains the symptom.

- Entry point: request, job, consumer, cron, UI action, or external event
- Internal path: service/function/task sequence with file references
- State changes: DB rows/fields, status transitions, cache, messages, offsets
- External calls: request/response contract and failure meaning
- Timing model: split queue, dependency, processing, and user timeout windows
- Failure point: where the bad state or error first enters the flow

Separate:

- current operating flow;
- behavior permitted by code;
- SQL/DB row unit and 1:1 versus 1:N cardinality;
- runtime state actually observed.

### 3. Analyze Causes

Rank causes instead of flattening them. Form hypotheses from independent lanes:
runtime/logs, code, DB/data, configuration, external dependency, and change
history. Refute the leading hypothesis before recommending a fix.

For each cause:

- Claim: mechanism that produced the symptom
- Evidence for: concrete supporting facts
- Evidence against: facts that constrain it
- Confidence: High / Medium / Low
- Blast radius: other affected paths
- Discriminator: next check that confirms or rejects it
- Refuter result: strongest contradiction found, or why none was available

### 4. Design the Remedy

- Immediate mitigation: reduce impact now
- Root-cause fix: smallest change that removes the mechanism
- Regression coverage: test/probe/assertion that fails before the fix
- Operational follow-up: alert, dashboard, runbook, rollback, communication
- Rejected option: tempting workaround and why it is weaker

When the fix changes business-rule ownership or state transitions, use
`domain-modeling-gate`. Keep incident evidence separate from architecture
preference.

### 5. Verify Resolution

- Local proof: reproduction, targeted test, replay, or code-path check
- Runtime proof: artifact, API response, DB query, queue state, Sentry trend,
  external response, or successful job
- Stop condition: exact observation that proves resolution
- Remaining risk: what is still unproven

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

Use Korean by default when the user wrote in Korean. Preserve exact technical
nouns.

```markdown
## 흐름
- [entrypoint] -> [service/task] -> [DB/external system] -> [failure point]

## 원인
1. [원인 후보] - 신뢰도: High/Medium/Low
   - 직접 근거:
   - 반대/제한 근거:
   - 반박 검증:
   - 다음 확인:

## 분석
- 왜 이 증상이 나오는지:
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

For Slack-ready output, compress the same evidence:

```markdown
[요약]
- 현상:
- 원인:
- 영향:
- 조치:
- 검증:
- 남은 리스크:
```

## Quality Bar

A good response:

- starts with business/user-visible flow, not only stack frames;
- separates direct evidence, inference, and unknowns;
- names the exact stage where the failure enters;
- distinguishes the trigger from the root mechanism and control gap;
- includes a minimal root-cause fix rather than symptom masking;
- defines runnable verification and a clear stop condition.
