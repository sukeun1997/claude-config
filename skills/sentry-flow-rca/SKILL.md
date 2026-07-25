---
name: sentry-flow-rca
description: "End-to-end Sentry issue flow and root-cause analysis. Use when a user provides a Sentry URL or issue ID and asks for full flow tracing, caller service, failure point, recent fixing or introducing commits/PRs, recurrence state, confirmation SQL, root cause, impact, and fix options."
---

# Sentry Flow RCA

Turn a Sentry issue into an evidence-backed incident analysis: request and
caller, code path, failure point, upstream input, relevant history, recurrence,
row-level SQL proof, impact, and fix options.

Prefer Korean output for Korean requests. Separate evidence from inference and
mark confidence for cross-repo caller claims.

## Workflow

1. **Collect Sentry evidence**
   - Fetch the issue and at least one recent event with configured tools.
   - Capture issue/message, first/last seen, count, project, environment,
     release, transaction, culprit, logger, exception, frames, tags, request,
     and relevant breadcrumbs.
   - Redact tokens, cookies, PII, and unnecessary headers.

2. **Build the Sentry 기준 flow**
   - Start from request/runtime evidence, not a nearby remembered issue.
   - Trace route, view/controller, serializer/parser, service/domain function,
     helper/client, and exact failure line with file references.
   - Separate current operating flow, code-permitted behavior, DB row unit, and
     observed runtime state.

3. **Trace cross-repo callers**
   - Use request evidence such as route, `Referer`, `Origin`, `User-Agent`,
     transaction, tags, and parameters before searching sibling repos.
   - Search likely callers such as `admin`, `loan-screening`, `investment`,
     `banking-report`, and other checked-out services with targeted patterns.
   - Distinguish browser-origin and server-to-server calls.
   - State caller confidence as confirmed, likely, possible, or unsupported.

4. **Find relevant change history**
   - Use `git log -S/-G`, blame/show, PR search, release SHAs, and deployed
     ancestry on the failing path and caller.
   - Compare change dates with `firstSeen` without treating timing as causality.
   - Classify history as latent bug, exposure change, triggering data/input
     change, or unrelated/noise.
   - Check `lastSeen`, recent events, releases, traffic validity, and triggering
     data before saying the issue no longer recurs.

5. **Prepare confirmation SQL**
   - Resolve identifiers explicitly: loan, application, user, virtual loan,
     external request, or domain-specific IDs.
   - Provide read-only copy-runnable SQL, what each query proves, and expected
     healthy/broken row shapes.
   - Use narrow indexed predicates and `EXPLAIN` when query safety is uncertain.
   - Do not provide mutation SQL unless the user asks for an operation plan.

6. **Reproduce minimally**
   - Reuse the exact event payload when possible.
   - Prefer targeted service/unit reproduction before broad integration tests.
   - State environment and credential gaps explicitly.

7. **Produce and challenge the RCA**
   - Lead with the most likely mechanism, then show flow and evidence.
   - Distinguish trigger, root mechanism, and control/detection/recovery gap.
   - Refute the leading cause and record the strongest contradictory evidence.
   - Recommend the minimum fix at the correct layer plus regression and runtime
     verification.
   - Use `domain-modeling-gate` if the fix moves business ownership, states, or
     invariants.

## Output Shape

1. `결론`
2. `Sentry 증거`
3. `전체 호출 Flow`
4. `흐름 중 문제 지점`
5. `원인과 반박 검증`
6. `최근 커밋/PR 및 재발 여부`
7. `확인 SQL`
8. `해결방안`
9. `검증과 남은 불확실성`

For `전체 호출 Flow`, identify whether the path is admin/browser,
`loan-screening`, `investment`, another service, or unsupported by evidence.
For SQL, include a one-line interpretation that confirms or rejects the
hypothesis.

## Senior / CTO Lens

- Why did prevention/detection controls miss the issue?
- Can retry, concurrency, partial failure, or a second entry point recreate it?
- Can operators detect, audit, replay, and repair the state?
- Which service/team owns the rule and the fix?
- What compatibility, rollout, rollback, and cross-service risks remain?

Keep systemic follow-ups separate from the minimum incident fix.
