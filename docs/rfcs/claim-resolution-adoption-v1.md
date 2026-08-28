# RFC: Local Ledger Claim Resolution Adoption v1

Status: Experimental independent consumer adoption

## Decision

Local Ledger consumes the released `claim.resolve:v1` primitive without giving
the core repository, generator, or another product authority over its release
decision. The adoption observes immutable Core v0.3.0-dev and Local Ledger
v0.5.0-dev release assets. It performs no repository writes and introduces no
cross-project required gate.

## Released claim boundary

The readiness v1 report publishes five resolution fields per scenario:
`state`, `stage`, `step`, `reason`, and `next_operation`. It does not publish an
`unknown_class` field. This adoption therefore does not claim that the released
report already contained six fields. It records exactly fifteen released fields
across three scenarios and binds the missing UNKNOWN type explicitly in a Gooo
activity value program.

The released scenarios are one CLOSED release decision, one UNKNOWN missing
runbook decision, and one REFUTED source-snapshot decision. Core observes
eighteen fields across the corresponding three six-field claim tuples. The
UNKNOWN class denominator is one, with the exact value `DIRECT_MISSING`.

## User context

The claim adoption remains attached to the released user-facing inventory:
six files, two descendant directories, seven Go physical lines, and twenty-eight
Gooo physical lines. These are four observed facts, not a quality score.

## Fail-closed behavior

A missing core receipt is UNKNOWN at
`CORE_RECEIPT / RESOLVE_MISSING_RUNBOOK_CLAIM` and requests the pinned receipt.
A changed released claim, a changed UNKNOWN class, an accepted invalid core
decision, or a repository-write authority escalation is REFUTED. No aggregate
score or successful scenario can hide those states.
