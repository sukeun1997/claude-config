---
name: backend-code-quality-review
description: "Senior/CTO-level backend code quality and architecture review for the user's Python/Django and Kotlin/Spring work. Use for clean code, naming, SOLID, OOP, DDD, Rich Domain, responsibility ownership, architecture, production readiness, or when the user wants junior blind spots identified from a PR, diff, file, or design."
---

# Backend Code Quality Review

Use this when the user wants more than "does it work?" Focus on code that is
easy to change safely in Kotlin/Spring and Python/Django.

## Purpose

- behavior and production risk first;
- architecture and responsibility boundaries;
- SOLID, OOP, DDD, and Rich Domain versus transaction-script fit;
- readable control flow and names that reveal domain intent;
- operational recovery, auditability, rollout, and team ownership;
- clean-code improvements worth the PR cost;
- verification evidence rather than taste-only comments.

Use `python-deep-review` for a Python/Django deep pipeline and the configured
Kotlin/Spring review pipeline for framework-specific behavior/security/API
checks. Use `domain-modeling-gate` for the complete domain sketch when business
terms, invariants, state transitions, aggregate boundaries, or Rich Domain
placement are material. Other reviews should apply only the relevant lens.

## Perspective Ladder

Review every change at the lowest relevant level and climb only while evidence
supports it.

1. Correctness now
   - intended behavior, edge cases, data integrity, security, compatibility;
2. Change safety
   - readable control flow, responsibility, tests, dependency direction;
3. Domain integrity
   - decision ownership, invariants, state transitions, transaction unit;
4. Production operation
   - concurrency, idempotency, observability, retry/recovery, rollout/rollback;
5. Architecture and organization
   - cross-service coupling, ownership, change amplification, long-term cost.

Do not turn levels 4-5 into speculative blockers. Report them as an architecture
watch or follow-up unless the current change creates a concrete risk.

## Review Order

1. Behavior and safety
   - Does the change preserve behavior except the intended delta?
   - Are transaction, DB, message, retry, permission, and error boundaries safe?
2. Responsibility boundary
   - Does each class/function have one coherent abstraction-level job?
   - Are validation, lookup, transformation, mutation, logging, and response
     selection mixed in a way that will be hard to change?
3. Domain model and DDD
   - Are domain terms consistent across code, data, events, and tests?
   - Is policy sitting with the right owner: entity/value object, application
     service/use case, repository/query, serializer/controller?
   - Is the model richer because it protects an invariant, or only because a
     pattern looks sophisticated?
4. SOLID and OOP
   - Apply SRP/OCP/LSP/ISP/DIP only to concrete local change pressure.
   - Prefer composition or a small policy when inheritance obscures behavior.
5. Naming and readability
   - Names reveal domain meaning and abstraction level.
   - Boolean names read as predicates and side effects are not hidden.
   - Happy and failure paths are easy to scan.
6. Tests and verification
   - Tests prove behavior boundaries, not only helpers.
   - Add integration evidence when risk crosses framework boundaries.
7. Senior / CTO blind spots
   - What happens on duplicate execution, partial failure, retry, or concurrency?
   - Can operators detect and repair the state without code archaeology?
   - Are audit/history, compatibility, rollout, and rollback preserved?
   - Which service/team owns the rule and its next likely change?
   - Is local convenience creating distributed coordination or migration cost?

## Rich Domain Decision Bar

Recommend domain-owned behavior when:

- one entity/value object/policy clearly owns the decision;
- the rule protects a named invariant or state transition;
- the behavior can be tested without framework or I/O setup;
- multiple entry points currently duplicate or bypass the rule.

Keep a transaction script/application service when:

- the work is mostly orchestration across repositories/external systems;
- no stable invariant or aggregate boundary is identified;
- the rule changes with workflow/policy rather than object state;
- moving behavior would hide I/O, transaction, or failure semantics.

An anemic object is not automatically wrong, and an entity method is not
automatically Rich Domain. Judge ownership, invariant protection, and change
cost.

## Stack-Specific Lens

### Kotlin/Spring

- Constructor injection with immutable dependencies.
- `@Transactional` placement, proxy/self-invocation, propagation, read-only,
  rollback, and event/`afterCommit` timing.
- Kotlin null safety and platform-type validation.
- JPA entity equality, lazy loading, N+1, cascade, and flush behavior.
- Treat JPA relationships as persistence mappings, not aggregate proof.
- DTO/command/result names match their boundary and intent.
- Sealed types or strategy dispatch only for stable repeated branching.
- No unstructured coroutines or parallel JPA work hidden inside a transaction.

### Python/Django

- QuerySet permission/visibility filters are not bypassed later.
- Review `transaction.atomic`, `on_commit`, signals, Celery enqueue timing, and
  retry/idempotency as one failure model.
- Views/serializers/admin/tasks translate at boundaries instead of owning policy.
- Use model/value behavior for object-owned decisions, application services for
  multi-model/external orchestration, and QuerySets/managers for query policy.
- Keep tests at the behavior boundary: API/view tests for contracts, focused
  unit tests for pure policies.
- Names use domain language instead of leaking ORM implementation details.

## Option Comparison

For non-trivial feedback, compare:

1. Keep current implementation
   - when cleanup would be taste-only;
2. Small cleanup in the current PR
   - when naming, responsibility, or a boundary repair reduces review risk;
3. Separate follow-up refactor
   - when cleaner architecture is valuable but too broad for the current fix.

Do not ask for abstraction merely because a pattern exists. Name the concrete
future change, bug, or operational failure it prevents.

## Finding Bar

Report a finding only for:

- behavior bug or production risk;
- unclear responsibility likely to cause future bugs;
- misleading naming/readability;
- SOLID/OOP/DDD issue with local evidence;
- missing test at the actual behavior boundary.

Low-confidence or subjective suggestions belong under `Non-blocking` or
`Follow-up`, not as blockers.

Every architecture finding must include:

- concrete bug/change/operational failure prevented;
- smallest viable boundary repair;
- migration/rollout cost when non-local;
- current PR versus separate task placement.

## Output Shape

```md
Verdict:
- GO / GO for review, not merge / NO-GO

현재 동작과 위험:

Junior blind spots caught:
- <invariant/concurrency/recovery/ownership issue or 없음>

선택지:
1. 현재 구현 유지
2. 현재 PR에서 작은 정리
3. 별도 후속 리팩토링

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
