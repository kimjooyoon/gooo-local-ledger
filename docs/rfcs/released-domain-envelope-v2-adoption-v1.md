# Released-domain envelope v2 adoption candidate

This candidate is Local Ledger's product-owned implementation of projecting the
eight typed dependency relations in the released `project-plan.json` into the
immutable released-domain envelope v2 format. The released envelope's
`project.json.authority.projection_owner` is `INTERCHANGE_SPECIFICATION` as
required by the immutable consumer kit; the local adoption report separately
records `envelope_semantic_authority: INTERCHANGE_SPECIFICATION` and
`projection_implementation_owner: LOCAL_LEDGER`. Local Ledger owns the
implementation and its released evidence, while the Interchange specification
owns the envelope authority and read-only consumer conformer.
This is an adoption candidate, not a new release, merge authorization, or
semantic-truth claim.

## Local-only denominator

The product evaluator uses its own fixed denominator. It does not copy the
Interchange kit's generic LOCAL/DESIGN/INFRA release denominator. There are
exactly 12 cells and exactly 12 Gooo activities, with this one-to-one mapping:

| Cell | Gooo activity |
| --- | --- |
| `CORE_RELEASE` | `ObserveCurrentCoreRelease` |
| `INTERCHANGE_SPEC_RELEASE` | `ObserveInterchangeSpecRelease` |
| `LOCAL_RELEASE` | `ObserveLocalProductRelease` |
| `META_ACTIVITY_AUTHORITY` | `ObserveMetaActivityAuthority` |
| `LOCAL_DEPENDENCY_SOURCE` | `ObserveLocalDependencySource` |
| `PRODUCT_PROJECTION` | `ProjectProductEnvelope` |
| `EIGHT_FILE_ENVELOPE` | `PublishEightFileEnvelope` |
| `READ_ONLY_CONFORMANCE` | `VerifyReadOnlyConformance` |
| `UNKNOWN_CAUSALITY` | `PreserveUnknownCausality` |
| `DETERMINISTIC_REPLAY` | `VerifyDeterministicReplay` |
| `REFUTED_COUNTEREXAMPLES` | `RefuteCounterexamples` |
| `AUTHORITY_BOUNDARY` | `PreserveAuthorityBoundary` |

FOUNDATION, COHERENCE, and REGRESSION each contain four cells. DRIVER,
OUTCOME, and GUARDRAIL each contain four cells. A normal candidate closes
12/12. Each cell's evaluator fact has the same name and meaning as the cell;
unrelated Design or Infra releases are not used to close a Local cell.

The normal run observes 1/1 product-owned projection implementation, with the
exact authority split above, plus 8/8 envelope files,
8/8 typed relations, 8/8 evidence anchors, 8/8 resolutions, and 10/10
read-only conformer checks. Deterministic replay reports source receipt
comparison 1/1 separately from physical file comparison 8/8. The eight-file
count is the product envelope output and is not the kit archive's generic
denominator.

## Evidence order and evaluator semantics

The generator is authorized only by the current run's 12 Gooo activity
receipts and released product evidence. Facts are assembled from observed
bundle `project.json` counts and NDJSON line counts, the kit conformer report,
replay/file-comparison results, checksum and payload digests, immutable input
records, and the runtime/inventory snapshots. Expected denominator values are
constants; observed values are not pre-filled with those expectations.

The workflow first evaluates a malformed `UNKNOWN` receipt and a `FIXED_POINT`
receipt. Both must produce actual `FAIL_CLOSED` reports; `FIXED_POINT` must
refute all 12 cells. It then removes the actual
`VerifyReadOnlyConformance` receipt and evaluates that input. The resulting
report must contain exactly two UNKNOWN cells: one `DIRECT_MISSING` and one
`DEPENDENCY_BLOCKED`, with `stage`, `step`, `reason`, `unknown_class`,
`next_operation`, and `blocked_by` preserved on every case. The final normal
run may close `UNKNOWN_CAUSALITY` only from that observed report, and may close
`REFUTED_COUNTEREXAMPLES` only from the two observed fail-closed reports.

An input Core UNKNOWN is accepted only when decision is `UNKNOWN`, claim state
is `UNKNOWN`, occurrences is `0`, reason is `ACTIVITY_NOT_FOUND`, and all six
coordinates are present. Malformed UNKNOWN and `FIXED_POINT` are REFUTED;
known REFUTED contradictions take precedence over UNKNOWN.

The checkout explicitly binds to
`github.event.pull_request.head.sha || github.sha`, so the checked-out subject
and report subject SHA are identical. The projector receives the repository
root and rejects an output at that root or below it with exit 65. CI uses only
caller-owned temporary output and observes `repository_writes=0`.

## Adoption, utility, and authority

Because no new Local Ledger release is produced here, released adoption is
`0/1 UNKNOWN`. No external user evidence exists yet, so external utility is
`0/1 UNKNOWN`; an improvement is UNKNOWN unless an exact before/after pair is
provided. The report declares one external-utility opportunity and zero
external-utility evidence.

The report records normal, UNKNOWN, and REFUTED case counts; Gooo activity
count; generated artifact count; the exact specification projection owner and
product implementation owner; user-path count; allowed and forbidden
authority; Go/Gooo files and physical lines; descendant directories; regular
files with the root README excluded from inventory; peak RSS KiB; wall ms; and
the zero values for repository writes, local test executions, and
cross-project required gates. Swapping either authority value is REFUTED and
cannot close the product-owned projection cell. Product generation is limited
to caller-owned temporary output. The Interchange CI is consumed as a released
kit and is not a required cross-project gate.
