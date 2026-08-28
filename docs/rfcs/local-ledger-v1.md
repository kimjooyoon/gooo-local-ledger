# RFC: Gooo Local Ledger v1

Status: Experimental vertical slice

## Decision

Local Ledger is a read-only decision ledger for one exact project snapshot. It
does not execute a build graph or modify the project. Its user output is a
release decision plus the first exact unresolved or refuted coordinate.

## Fixed denominator

The denominator has twelve cells and is bound to twelve released Gooo Activity
nodes. FOUNDATION identifies authority and observed facts, COHERENCE checks
required relationships, and REGRESSION requires runtime/resource/effect/user
observations. These are proof choices rather than scores.

The standalone readiness policy is part of project authority. It declares a
read-only effect, zero cross-project branch inputs, zero external required
gates, zero required local test executions, and no root README requirement.
The external-gate and repository-write indicators are both bound to the
`ObserveReadOnlyEffect` Gooo activity; an unbound policy number cannot close
the authority cell.

## Inventory semantics

Files and descendant directories are counted under the candidate root. Go and
Gooo metrics are physical line counts, including blank and comment lines. The
project root itself is excluded from the directory count. A root README is not
required; documentation and operations evidence are explicit manifest paths.

## Resolution behavior

A missing runbook is UNKNOWN at `OPERATIONS / OBSERVE_RUNBOOK` with next
operation `PROVIDE_OPERATIONS_RUNBOOK`. The USER_DECISION cell remains UNKNOWN
because its prerequisite is unresolved. A changed source snapshot is REFUTED at
`SOURCE / VERIFY_SOURCE_SNAPSHOT`; the user decision is also refuted.

No heuristic, natural-language confidence, or aggregate score may close either
case.

## Resource observation

CI reports released `gooo graph dump` peak RSS and wall time as observed values.
v1 has no arbitrary performance threshold, so resource presence closes the
sample cell but a smaller number is not automatically called an improvement.

## Non-claims

Local Ledger does not claim build success, runtime health, source-span binding,
or deployment readiness. It does not generate or repair missing evidence.
An immutable released CLI asset is an observed input, not a live cross-project
readiness gate.
