# Gooo Local Ledger

Gooo Local Ledger answers one user question:

> Can this exact project snapshot be released? If not, which evidence is
> missing, at what stage, and what observation should happen next?

It is a read-only decision layer, not a task runner, build cache, package
manager, or automatic repair tool. It consumes the released Gooo CLI and keeps
all reports outside the input project.

## First vertical case

The fixture contains a small Gooo authority, one Go entry point, project
documentation, an operations runbook, and release notes. Its immutable
readiness denominator has exactly twelve cells:

| Cell | Proof choice |
|---|---|
| PROJECT_AUTHORITY | FOUNDATION |
| SOURCE_SNAPSHOT | FOUNDATION |
| FILE_INVENTORY | FOUNDATION |
| LANGUAGE_LINES | FOUNDATION |
| BUILD_ENTRYPOINT | COHERENCE |
| DOCUMENTATION | COHERENCE |
| OPERATIONS_RUNBOOK | COHERENCE |
| RELEASE_NOTES | COHERENCE |
| RELEASED_GOOO_BINDING | FOUNDATION |
| RESOURCE_SAMPLE | REGRESSION |
| READ_ONLY_EFFECT | REGRESSION |
| USER_DECISION | REGRESSION |

CI evaluates three read-only views:

- ready fixture: `12/12 CLOSED`, decision `RELEASE_READY`;
- runbook removed from a temporary copy: `10/12 CLOSED`, decision
  `NOT_READY`, with the missing stage and next operation;
- Go source changed in a temporary copy: `REFUTED` at
  `SOURCE / VERIFY_SOURCE_SNAPSHOT`.

## Human indicators

The CI summary shows exact observed numbers rather than a qualitative score:

- descendant directory count;
- file count;
- physical Go lines;
- physical Gooo lines;
- required artifacts observed;
- released CLI receipts;
- semantic activity bindings;
- graph command peak RSS in KiB and wall time in milliseconds;
- repository writes.

The candidate project root is not required to contain a `README.md`.
Documentation evidence is an explicit path in the project contract.

The standalone readiness policy also fixes the operational boundary at
`READ_ONLY`, external required gates `0`, cross-project branch inputs `0`, and
required local test executions `0`. The external-gate metric is bound to the
existing `ObserveReadOnlyEffect` Gooo activity rather than being reported as an
unbound configuration number.

See [the v1 RFC](docs/rfcs/local-ledger-v1.md).
