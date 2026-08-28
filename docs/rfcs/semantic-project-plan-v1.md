# Semantic Project Plan v1

## Decision

Local Ledger exposes one read-only project planning path whose semantic authority is a Gooo program.
The product invokes the released Core v0.4 claim-dependency command and projects its receipt into JSON and Markdown.

The generated packet describes structural dependency only.
It does not claim that a task is complete, a proposition is true, a state was propagated, or a repository should be modified.

## User path

The package accepts a released Gooo executable, one project program, four conformance fixtures, one packet contract, and an output directory outside the source repository.

It emits project-plan.json, project-plan.md, and five released-command evidence receipts.

The normal example contains six activities and eight typed dependencies.
Its dependency-kind counts are requires 3, supports 2, contradicts 2, and failure-entailment 1.

## Recovery and refusal

A missing producer lowers resolution to UNKNOWN and preserves six coordinates: stage, step, reason, unknown_class, next_operation, and blocked_by.

Unsupported dependency kinds, ambiguous producers, and cycles fail closed as REFUTED.
The packet generator never converts those states to a successful plan.

## Measurement

Conformance and utility are separate.

Conformance is the number of CLOSED declared cells divided by twelve declared cells.
Utility is the number of externally evidenced use cases divided by declared use cases.
This release provides a closed example path but does not claim external utility.

The CI report publishes exact activity, dependency, artifact, replay, source-line, directory, file, time, memory, write, local-test, and cross-project-gate counts.

## Authority boundary

The generator writes only to its caller-provided output directory.
It cannot mutate a repository, repair a project, merge a change, promote a Core primitive, or authorize another project.
All cross-project inputs are immutable release assets, and required cross-project gates remain zero.
