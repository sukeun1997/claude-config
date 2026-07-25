---
name: backend-code-quality-review
description: "Senior/CTO-level backend code quality and architecture review for the user's Python/Django and Kotlin/Spring work. Use for clean code, naming, SOLID, OOP, DDD, Rich Domain, responsibility ownership, architecture, production readiness, or when the user wants junior blind spots identified from a PR, diff, file, or design."
---

# Backend Code Quality Review

Use this for backend review requests where the user wants more than "does it
work?" Focus on code that is easy to change safely in the user's main stacks:
Kotlin/Spring and Python/Django.

## Purpose

Review backend code through the user's preferred quality lens:

- current behavior and production risk first;
- architecture and responsibility boundaries;
- SOLID, OOP, and DDD fit;
- Rich Domain versus transaction-script fit;
- readable control flow and small names that reveal domain intent;
- operational recovery, auditability, rollout, and team ownership;
- clean-code improvements that are worth the PR cost;
- verification evidence, not taste-only comments.

## When To Use

Activate when the user asks about:

- SOLID, OOP, DDD, clean code, naming, readability, or responsibility clarity;
- Spring/Kotlin or Python/Django PRs and local diffs;
- whether current implementation is architecturally acceptable;
- "깔끔한 코드", "가독성 좋은 코드", "네이밍 좋은 코드", or "책임이 명확한 코드";
- comparing current implementation with a cleaner refactor.

Use `domain-modeling-gate` for the complete domain sketch when business terms,
invariants, state transitions, aggregate boundaries, or Rich Domain placement
are material. Other review skills should apply only the relevant lens instead
of duplicating the full sketch.

<!-- harness-specific:start -->
Use `/ecr` for Kotlin/Spring behavior/security/API review and
`python-deep-review` for Python/Django deep review when those language-specific
pipelines are explicitly requested.
<!-- harness-specific:end -->

When the change carries domain meaning, use `lecture-review-lens` to select
relevant current lecture notes and turn them into review questions before
forming findings. A lecture claim is a hypothesis source, not evidence, and the
lens must not make a mechanical or infrastructure-only review broader.

## Perspective Ladder

Review every change at the lowest relevant level and climb only while evidence
supports it.

1. Correctness now
   - intended behavior, edge cases, data integrity, security, compatibility;
2. Change safety
   - readable control flow, responsibility, tests, dependency direction;
3. Domain integrity
   - business decision ownership, invariants, state transitions, transaction unit;
4. Production operation
   - concurrency, idempotency, observability, retry/recovery, rollout/rollback;
5. Architecture and organization
   - cross-service coupling, ownership, change amplification, long-term cost.

Do not turn levels 4-5 into speculative blockers. Report them as an architecture
watch or follow-up unless the current change creates a concrete risk.

## Review Order

1. Behavior and safety
   - Does the change preserve user-visible behavior except the intended delta?
   - Are transaction, DB, message, retry, permission, and error boundaries safe?
2. Responsibility boundary
   - Is each function/class doing one job at its abstraction level?
   - Are validation, lookup, transformation, mutation, logging, and response
     selection mixed in a way that will be hard to change?
3. Domain model and DDD
   - Are domain terms used consistently?
   - Is business policy sitting in the right layer: entity/value object,
     service/use case, repository/query, serializer/controller?
   - Are aggregate/state-transition rules explicit enough?
   - Is the proposed model richer because it protects an invariant, or only
     because a pattern looks more sophisticated?
4. SOLID and OOP
   - SRP: one reason to change.
   - OCP: avoid repeated branching when extension is likely.
   - LSP/ISP/DIP: flag only concrete violations, not textbook trivia.
   - Prefer composition or small policy helpers when inheritance would obscure
     behavior.
5. Naming and readability
   - Names should reveal domain meaning and abstraction level.
   - Boolean names should read as predicates.
   - Avoid abbreviations unless local domain convention proves them.
   - Control flow should make the happy path and failure paths easy to scan.
6. Tests and verification
   - Tests should prove the behavior boundary, not only the helper.
   - Prefer one integration/API test when the risk crosses framework boundaries.
   - Report exact commands run and any environment gaps.
7. Senior / CTO blind spots
   - What happens on duplicate execution, partial failure, retry, or concurrency?
   - Can an operator detect and repair the bad state without code archaeology?
   - Does the change preserve audit/history requirements and compatibility?
   - Which service/team owns the rule and its next likely change?
   - Is a local convenience introducing distributed coordination or a broad
     migration/rollback burden?

## Rich Domain Decision Bar

Recommend domain-owned behavior when:

- one entity/value object/policy clearly owns the decision;
- the rule protects a named invariant or state transition;
- the behavior can be tested without framework or I/O setup;
- multiple entry points currently duplicate or bypass the rule.

Keep or prefer a transaction script/application service when:

- the work is mostly orchestration across repositories/external systems;
- no stable invariant or aggregate boundary has been identified;
- the rule changes with workflow/policy rather than object state;
- moving behavior would hide I/O, transaction, or failure semantics.

An anemic object is not automatically wrong, and a method on an entity is not
automatically Rich Domain. Judge ownership, invariant protection, and change
cost.

## Stack-Specific Lens

### Kotlin/Spring

- Constructor injection with immutable dependencies.
- `@Transactional` boundary and event publication timing.
- Proxy/self-invocation, propagation, read-only, and `afterCommit` semantics.
- Kotlin null-safety: no `!!` outside tightly justified test code.
- JPA entities: avoid `data class`, unstable equality, and lazy-loading surprises.
- Treat JPA relationships as persistence mappings, not aggregate proof.
- DTO names: `Request`, `Response`, `Command`, `Result` should match use.
- Sealed types or strategy dispatch when domain branching is stable and repeated.
- Coroutine usage: no `GlobalScope`; avoid `async` inside JPA transactions.

### Python/Django

- Queryset boundaries: filters, permissions, and visibility rules must not be
  bypassed by a later manager call.
- Check `transaction.atomic`, `on_commit`, signals, Celery enqueue timing, and
  retry/idempotency as one failure model.
- Views should not hide business policy that belongs in a service/query helper.
- Serializer choice should not accidentally perform unsafe DB lookups.
- Keep model methods for object-owned decisions; use application services for
  multi-model/external orchestration and QuerySets/managers for query policy.
- Prefer small helpers when they isolate a domain policy or framework workaround.
- Keep tests close to the behavior boundary: view/API tests for view contracts,
  unit tests for pure policy helpers.
- Python naming: functions are verbs, predicates start with `is_`, `has_`, or
  local equivalents, and variables should not leak ORM implementation details
  when domain terms are clearer.

## Option Comparison

For non-trivial code-quality feedback, compare these options before the final
recommendation:

1. Keep current implementation
   - when behavior is correct and cleanup would be mostly taste;
2. Small cleanup in the current PR
   - when naming, responsibility, or helper extraction reduces real review risk;
3. Separate follow-up refactor
   - when a cleaner architecture is valuable but too broad for the current fix.

Do not ask for abstraction just because a pattern exists. The suggestion must
name the future change it makes safer.

## Finding Bar

Report a finding only when it is one of:

- behavior bug or production risk;
- unclear responsibility likely to cause future bugs;
- naming/readability issue that can mislead maintainers;
- SOLID/OOP/DDD issue with concrete local evidence;
- missing test at the actual behavior boundary.

If it is subjective or low confidence, put it under `Non-blocking` or
`Follow-up`, not as a blocking issue.

Every architecture finding must include:

- the concrete next bug/change or operational failure it prevents;
- the smallest viable boundary repair;
- migration/rollout cost when the change is not local;
- whether it belongs in the current PR or a separate design/refactor task.

## Output Shape

```md
Verdict:
- GO / GO for review, not merge / NO-GO

현재 동작과 위험:

Junior blind spots caught:
- <놓치기 쉬운 invariant/concurrency/recovery/ownership issue or 없음>

선택지:
1. 현재 구현 유지
   - 장점:
   - 실패 조건:
   - 검증:

2. 현재 PR에서 작은 정리
   - 장점:
   - 실패 조건:
   - 검증:

3. 별도 후속 리팩토링
   - 장점:
   - 실패 조건:
   - 검증:

판단 기준:

Findings:
- [Severity] <issue>
  - Evidence:
  - Impact:
  - Fix:

Non-blocking / Follow-up:

Senior / CTO architecture watch:
- Ownership:
- Operability/recovery:
- Compatibility/rollout:
- Next-change cost:

추천:

반박 요청:

검증:
```

Delete every `Senior / CTO architecture watch` line where you cannot name a
concrete failure or change cost, and drop the heading when all four go. Write
`없음` for `Junior blind spots caught` rather than inventing one. An unfilled
slot is signal; a filled empty slot buries the findings that matter.

## Comment Template

```md
Non-blocking: 현재 구현은 동작 관점에서는 괜찮아 보입니다. 다만 <responsibility/naming/test-boundary> 관점에서 <specific evidence> 때문에 다음 수정자가 오해할 수 있습니다. 현재 PR에서 작게 고친다면 <small fix> 정도가 적절하고, 범위가 커지면 별도 후속 PR로 분리하는 편이 안전해 보입니다.
```
