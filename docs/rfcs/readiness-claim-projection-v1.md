# RFC: Readiness Claim Projection v1

Status: Experimental user-path projection

## Decision

Local Ledger projects a released five-field readiness claim into a temporary
Gooo activity value program. The released `claim.resolve:v1` primitive then
produces the six-field claim receipt. The projection does not alter the
released readiness report, the candidate project, or this source repository.

This closes a product gap left by v0.6.0-dev. That release proved three static
direct mappings, but the user-facing v1 readiness report still omitted
`unknown_class`. Projection v1 obtains the class from a declared twelve-entry
classification, never from a state name, score, or fallback guess.

## User path

The input is one immutable readiness report, the twelve-cell readiness
denominator, and the twelve-entry UNKNOWN classification. The output directory
is caller-owned and outside the observed repository. The projector emits one
Gooo source program and one projection receipt. The released compiler emits one
claim-resolution receipt.

Three released scenarios are fixed:

- `CLOSED`: release readiness is closed.
- `UNKNOWN`: the operations runbook is directly missing.
- `REFUTED`: the source snapshot contradicts the expected digest.

The input reports expose fifteen fields. The projected receipts expose eighteen
fields. The one additional field per scenario is `unknown_class`; only the
UNKNOWN scenario has the non-null value `DIRECT_MISSING`.

## Metaprogramming boundary

The claim tuple is not assembled as the final JSON result by the shell tool.
The shell tool validates released evidence and emits a deterministic Gooo value
program. The released Gooo compiler validates and resolves that program. Both
the generated source and compiler receipt are retained as CI evidence.

The projection authority contains twelve Gooo activities. Each denominator cell
names exactly one activity, one Munchausen proof choice, and one indicator
class. FOUNDATION, COHERENCE, and REGRESSION are four cells each. DRIVER,
OUTCOME, and GUARDRAIL are four cells each.

## Fail-closed classification

An UNKNOWN coordinate consists of `stage`, `step`, `reason`, and
`next_operation`. It must match exactly one declared entry. Zero matches are
`REFUTED / UNKNOWN_COORDINATE_UNDECLARED`. More than one match or any duplicate
classification coordinate is REFUTED. A missing compiler receipt remains
UNKNOWN at the exact claim-receipt step. A changed compiler tuple is REFUTED and
cannot be hidden by the other two successful scenarios.

## Exact release evidence

A projection release requires:

- projection cells: `12/12`
- released readiness reports: `3/3`
- released source claim fields: `15/15`
- generated Gooo claim programs: `3/3`
- resolved core claim receipts: `3/3`
- projected claim fields: `18/18`
- UNKNOWN classification entries: `12/12`
- classification counterexamples: `2/2`
- deterministic replay comparisons: `9/9`
- local tests: `0`
- source repository writes: `0`
- cross-project required gates: `0`

Memory, elapsed time, repository files, descendant directories, and per-file Go
and Gooo physical lines are observations. They are not quality scores and do
not imply improvement.

## Non-claims

Projection v1 does not claim build success, runtime health, deployment
readiness, automatic repair, semantic equivalence with another project, common
generator authority, or central orchestration authority. Root README readiness
is excluded.
