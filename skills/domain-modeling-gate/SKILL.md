---
name: domain-modeling-gate
description: Produce the domain model sketch before designing backend code, when business terms are ambiguous or an aggregate/state/ownership boundary is about to change. Covers sale, EOD, loss, settlement, bond, repayment and similar state machines, and specs already rewritten several times. Use backend-code-quality-review instead when reviewing existing code.
---

# Domain Modeling Gate

Force business language and invariants to be explicit before code design.

## When To Use

- Sale, EOD, loss, settlement, bond, repayment, reconciliation, or state-machine work.
- Any feature where nouns, verbs, and events are ambiguous.
- Any domain spec that has already been rewritten several times.
- Before changing aggregate boundaries, event contracts, or workflow state.

Before completing the sketch, use `lecture-review-lens` when local lecture
notes can sharpen questions about language, responsibility, cardinality,
lifecycle, or boundaries. Select notes live so future documents participate.
Do not copy a course conclusion into the model without code, data, policy, or
domain-expert evidence.

## Required Sketch

```markdown
## Domain Model Sketch

Current Operating Flow:
- <actor -> business action -> result>

Bounded Context:
- <context name and responsibility>

Ubiquitous Language:
- <business term / code term / exact definition>

Actors:
- <person or system responsible for each action>

Decision Ownership:
- <who owns the business decision / who only orchestrates or translates>

Core Concepts:
- Entities: <identity-bearing domain objects>
- Value Objects: <immutable descriptive values>
- Aggregates: <consistency boundaries>

Commands / Domain Actions:
- <business verb, actor, target, precondition>

Domain Events:
- <business fact, trigger, payload meaning>
- <integration or technical event, when distinct>

State Transitions:
- <from -> to, command/event, guard condition>

Invariants:
- <rules that must always hold>

Data Unit and Cardinality:
- <business unit / table or row unit / 1:1 or 1:N>

Transaction Boundary:
- <what must commit or roll back together>

External Systems:
- <upstream/downstream contract, adapter translation, failure meaning>

Failure and Recovery:
- <partial failure / retry / idempotency / audit / replay or manual recovery>

Evolution and Ownership:
- <likely next change / affected teams or services / compatibility and rollback>

Evidence and Unknowns:
- Confirmed: <code, test, schema, SQL, log, policy, or expert evidence>
- Inferred: <reasoned but unverified interpretation>
- Unknown: <question and fastest validation source>

Model Feedback:
- <implementation insight that must update language, model, code, docs, or tests>

Ambiguous Terms:
- <terms needing clarification or repository evidence>
```

## Rules

- Prefer event storming vocabulary before class names.
- Choose the smallest modeling depth that protects the current business rules:
  transaction script, application service plus explicit policies, or Rich Domain.
  Do not treat Rich Domain as the default maturity level.
- Keep business conversation, documentation, code names, and test scenarios on
  the same ubiquitous language; record intentional translations at adapters.
- Separate the current operating flow, behavior permitted by code, and DB row
  units before concluding that one representation is the domain model.
- Treat code as evidence of the current implementation, not proof that the
  business model or terminology is correct.
- Separate confirmed facts, inference, and unknowns. Route unresolved business
  meaning to the fastest code, data, policy, or domain-expert validation source.
- Treat unclear terms as blockers for broad implementation.
- Do not introduce a new abstraction until it protects a named invariant or boundary.
- If the existing code uses transaction scripts, keep that style unless the domain sketch justifies richer modeling.
- Distinguish decision ownership from orchestration. A service may load data,
  call collaborators, and commit a transaction without owning the business
  judgment it executes.
- Check architecture over time: auditability, recovery/replay, backward
  compatibility, rollout/rollback, cross-service coupling, and the team that
  will own the next likely change.

## Stack Mapping

Use local architecture as evidence; these are ownership heuristics, not mandatory
layers.

### Python/Django

- Put an invariant on a model or value object when one domain object owns the
  decision and the rule can be evaluated without infrastructure orchestration.
- Use an application service for multi-model workflows, transaction boundaries,
  external calls, task enqueueing, and use-case sequencing.
- Keep reusable query/visibility policy in a `QuerySet`, manager, or query
  service; do not hide mutations in query helpers.
- Keep serializers, views, admin actions, Celery tasks, and signal handlers thin:
  validate/translate at the boundary, then call an explicit use case.
- Do not force aggregate-style objects around Active Record models when a small
  policy function or transaction script protects the rule more clearly.

### Kotlin/Spring

- Put a business decision on an entity, value object, or domain policy when it
  protects a named invariant and can be tested without Spring.
- Use an application service/use case for repository coordination, transaction
  boundaries, authorization orchestration, and external adapters.
- Treat JPA associations as persistence mappings, not automatic aggregate
  boundaries. Verify consistency and loading requirements separately.
- Translate web/event/client DTOs at adapters. Keep framework annotations and
  transport status codes from becoming domain vocabulary.
- Publish domain facts and integration events deliberately; align publication,
  outbox, and `afterCommit` timing with failure semantics.

## Senior / CTO Challenge

Before approving a model, answer:

1. Which business decision is hardest to locate or test today?
2. Which invariant can be violated by concurrency, retry, partial failure, or a
   second entry point?
3. What is the smallest boundary that fixes that problem without a broad rewrite?
4. How will operators detect, recover, replay, or audit a failed transition?
5. Which likely next change becomes cheaper, and which coupling becomes more
   expensive?
6. Is the proposed boundary owned by one team, or does it create a distributed
   transaction or coordination burden?

## Verification

The final plan must map each acceptance criterion to at least one domain action,
event, state transition, or invariant from the sketch. It must also cover one
failure/recovery scenario for money movement, external integration, or async
work. Tests must name the business rule they prove, and the handoff must state
what they do not prove.
