---
name: kotlin-patterns
description: Evidence-first Kotlin/Spring backend patterns for implementation and review. Use when writing or reviewing .kt files, Spring Boot services, JPA transactions, coroutines, domain logic, Rich Domain, or architecture-sensitive Kotlin changes.
---

# Kotlin / Spring Patterns

Apply Kotlin idioms only after reading the repository's build, nearby code,
tests, and local rules. This skill supports the user's company Kotlin/Spring
work; it does not impose Haru, Kotest, MockK, WebFlux, or a particular layered
architecture on every repository.

## Evidence First

Before suggesting a pattern:

1. Inspect `build.gradle.kts`, version catalogs, compiler plugins, and the
   Spring/Kotlin/JDK versions actually used.
2. Sample nearby production code and tests for established conventions.
3. Distinguish an objective correctness/operability risk from a stylistic
   preference.
4. Preserve a transaction script when it is the smaller correct design. Apply
   `domain-modeling-gate` only when business ownership, invariants, states, or
   Rich Domain placement are material.

## Kotlin Idioms

- Prefer immutable references and values. Use `var` when lifecycle or framework
  behavior requires controlled mutation.
- Use nullable types to represent a real absence, not an unvalidated external
  contract. Translate and validate platform types at the boundary.
- Avoid `!!` in production code unless a proven invariant is documented at the
  same boundary; prefer an explicit guard or domain error.
- Choose scope functions for readability, not density. Nested `let`/`run` chains
  that hide control flow should be expanded.
- Use `data class` for value-like DTOs when generated equality/copy semantics are
  correct. Do not use it automatically for JPA entities or identity objects.
- Use sealed types when the state set is deliberately closed and exhaustive
  handling is valuable. Do not create a hierarchy for one branch.
- Use extension functions for behavior that reads naturally as an operation on
  the receiver and does not need hidden dependencies. Keep domain policy on its
  owner rather than disguising it as a generic extension.

## Writing Kotlin

Defaults for new code. Override any of these when the repository already does
something else consistently; Evidence First wins.

Scope function selection:

```
let   → nullable chain: value?.let { ... }
run   → initialize, then return a result
apply → configure the receiver and return it
also  → side effect (log, validate) that must not change the value
with  → several accesses to one already non-null receiver
```

Validate an external contract once at the boundary, then carry a non-null type
inward:

```kotlin
val amount = response.amount
    ?: throw ExternalContractViolation("amount missing: ${response.id}")
```

Structured concurrency for concurrent I/O:

```kotlin
suspend fun load(id: UserId): Dashboard = coroutineScope {
    val profile = async { profileClient.fetch(id) }
    val balance = async { balanceClient.fetch(id) }
    Dashboard(profile.await(), balance.await())
}
```

`Dispatchers.IO` for blocking I/O, `Dispatchers.Default` for CPU-bound work, and
never `GlobalScope`. Do not fan out repository calls with `async` inside one JPA
transaction; the connection is bound to the calling thread.

JPA entity shape:

```kotlin
@Entity
@Table(name = "loans")
class Loan(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,

    @Column(nullable = false)
    var status: LoanStatus,
) {
    fun settle(at: Instant) {
        require(status == LoanStatus.ACTIVE) { "cannot settle from $status" }
        status = LoanStatus.SETTLED
    }
}
```

`val` for identity, `var` only for fields the domain actually transitions, the
transition guarded by the entity that owns it. No `data class` for entities, no
`lateinit var`; rely on the `allOpen`/`noArg` compiler plugins.

Model domain failures as a closed hierarchy the boundary maps exhaustively.
Do not throw transport or framework exceptions from domain code.

## Spring and Transaction Boundaries

- Prefer constructor injection and explicit immutable dependencies.
- Verify `@Transactional` placement, proxy/self-invocation, propagation,
  isolation, `readOnly`, and exception rollback behavior from actual call sites.
- Align event publication, `on_commit`/`afterCommit`, outbox writes, and external
  calls with the failure semantics. A successful method return is not proof that
  every async side effect committed.
- Keep network calls and long-running work out of DB transactions unless the
  consistency tradeoff is intentional and tested.
- Treat retries as repeated executions: require idempotency, uniqueness, or a
  state guard where duplicate effects matter.

## JPA and Persistence

- Treat JPA relationships as persistence mappings, not automatic aggregate
  boundaries.
- Review entity equality/hash code, lazy loading, N+1 queries, cascade,
  `orphanRemoval`, collection mutation, and flush timing.
- Put object-owned invariants close to the entity/value object when they can be
  evaluated without infrastructure orchestration.
- Keep repository coordination, authorization orchestration, external adapters,
  and transaction sequencing in an application service/use case.
- Use DB constraints, locks, or optimistic versioning when an invariant must
  survive concurrency; an in-memory `if` check alone is insufficient.

## Rich Domain and Architecture

Apply `domain-modeling-gate` for the complete model. In Kotlin code, check:

- whether a service conditional is actually a decision owned by an entity,
  value object, or domain policy;
- whether moving behavior into the domain makes the invariant easier to test
  without hiding I/O or transaction boundaries;
- whether web/client/event DTOs are translated before entering domain language;
- whether domain facts and integration/technical events are distinguished;
- whether the proposed port, aggregate, strategy, or value object protects a
  named invariant or only adds ceremony.

Prefer a small boundary repair over a broad "clean architecture" rewrite.

## Coroutines

- Use structured concurrency; do not use `GlobalScope`.
- Do not assume blocking JPA work becomes safe or non-blocking inside a
  coroutine. Verify dispatcher and transaction-context behavior.
- Avoid parallel repository calls inside one JPA transaction unless connection
  and transaction propagation are explicitly supported.
- Propagate cancellation and preserve timeout/error meaning at external
  boundaries.

## Senior / CTO Blind Spots

For architecture-sensitive changes, ask:

1. What happens on duplicate execution, concurrent requests, partial failure,
   and retry?
2. Can operators detect, audit, replay, or repair the failed state?
3. What database/event/API compatibility and rollout/rollback work is required?
4. Which service and team own the business rule and its next likely change?
5. Does the local abstraction reduce change amplification, or move coupling
   across a network/transaction boundary?

## Verification

- Prefer focused module compilation and targeted tests from the repository's
  existing commands.
- Test business state transitions and invariants with business-language names.
- Add an integration test when risk crosses Spring/JPA/serialization/event
  boundaries.
- Report commands, outputs, environment constraints, and unverified runtime
  behavior.

Do not recommend a rewrite when the current code is correct, locally consistent,
and the proposed abstraction protects no concrete invariant or future change.
