# Generator v0.3 core receipt consumer

## Decision

The local ledger is the first product-shaped consumer of released Gooo activity-resolution semantics. It consumes only immutable public release assets. It does not import either producer repository, mutate its Gooo source, or replace the existing v0.1 readiness path.

This is an adjacent conformance path, not a compatibility claim for every Gooo v0.2 feature.

## Why a local project manager is the first closed case

A local project manager contains more semantics than a file counter but has a smaller external boundary than a design or infrastructure linker. Its release candidate already names the activities that create evidence, bind inputs, make a decision, and publish a receipt. The generator can therefore connect a human-visible metric to an executable Gooo declaration without inventing a proxy.

The closed user path is:

1. A user describes a release-candidate project in Gooo.
2. Released Gooo resolves the exact Activity selected for each evidence cell.
3. Released generator code converts those receipts into a generated project bundle.
4. The verifier checks the bundle without writing into the source repository.
5. CI displays exact denominators and degraded-resolution locations.

## Fixed denominator

This adoption has 6 completion units. Progress is the count of closed units, never a percentage inferred from effort.

| Unit | Closed only when |
|---|---|
| Immutable tools | Both release archives match their pinned SHA-256 values |
| Source semantics | Syntax, semantic hash, and graph are produced for the actual project.gooo source |
| Activity receipts | 11/11 meta receipts and 12/12 project receipts are CLOSED |
| Generated evidence | 12/12 cells are CLOSED and 6/6 generated files verify |
| Determinism | Two runs produce byte-identical bundles |
| Non-mutation | Repository writes are exactly 0 and local tests are exactly 0 |

The 12 evidence cells are partitioned twice:

| Proof | Denominator |
|---|---:|
| FOUNDATION | 4 |
| COHERENCE | 4 |
| REGRESSION | 4 |

| Indicator | Denominator |
|---|---:|
| OUTCOME | 3 |
| DRIVER | 5 |
| GUARDRAIL | 4 |

## Semantic authority

Graph nodes are allowed to provide derived identifiers and digests. They are not allowed to decide cardinality. Each metric cell is bound to a released `gooo/activity-cardinality-resolution/v1` receipt produced from an explicit selector and the real Gooo source.

Only the explicit core decisions `CLOSED`, `UNKNOWN`, and `REFUTED` are accepted. An absent receipt lowers resolution to `UNKNOWN`. An unrecognized value such as `FIXED_POINT` becomes `FAIL_CLOSED`. A release-identity mismatch refutes the identity cell and every dependent cell.

Every non-closed top-level claim exposes `stage`, `step`, `reason`, and `unknown_class` when applicable. Evidence does not erase a claim; it changes the claim state to `CLOSED` and preserves the receipt that closed it.

## Independence boundary

The core language, generator, and local ledger can release independently:

| Producer | Consumer pin | Coupling |
|---|---|---|
| Gooo | v0.2.0-dev tag object, commit, archive digest | Activity-resolution receipt schema only |
| Evidence generator | v0.3.0-dev tag object, commit, portable archive digest | Generator CLI and generated evidence schema |
| Local ledger | Existing project.gooo and profile | No producer source checkout |

Failure in this experimental path must not change the existing v0.1 readiness decision. A later compatibility claim requires a separate denominator.

## Parallel project portfolio

The next projects should not share an implementation repository or block one another:

| Project | First semantic object | First closed output | Current gate |
|---|---|---|---|
| Local project manager | Project, release candidate, evidence receipt | Verified generated project bundle | This RFC |
| Design-system code matcher | Design token/component/code binding | Match, ambiguity, and drift receipt | Independent public consumer |
| Infrastructure-service linker | HCL resource, OpenAPI operation, service symbol | Cross-layer dependency and drift receipt | Independent public consumer |
| Connection orchestrator | Released receipt references | Reproducible multi-project connection plan | Wait for the same pattern in at least 2 of 3 domains |

The orchestrator is deliberately delayed. Before two independent domains produce the same receipt relation, a shared connector would encode theory rather than observed repetition.

## Product value under experiment

The useful property is not new syntax for tasks that Go, HCL, OpenAPI, or design tools already perform. Gooo contributes a portable account of why a generated relation is closed, unknown, or refuted, which released semantic operation produced that state, and what next operation can raise resolution.

Positive results are evidence for one fixed denominator only. They are not evidence that the language is generally complete, commercially valuable, or preferable to existing languages.
