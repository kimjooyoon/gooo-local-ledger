# RFC: Independent evidence-generator consumer 1

## Decision

Consume the released `gooo-evidence-generator v0.2.2-dev` portable bundle in a
new parallel GitHub Actions workflow. Do not modify the existing local-ledger
readiness workflow, evaluator, Gooo source, fixtures, or root README.

## Authority split

- the generator release tag and portable asset digest authorize generator
  scripts and the repetition observation;
- released Gooo generates the meta graph from the bundled generator source;
- released Gooo generates the project graph from the existing local-ledger
  source;
- this repository owns the twelve-cell denominator and project profile;
- generated files exist only in runner temporary storage.

The generator copies the existing eight-asset local-ledger core lock without
normalizing it into the generator's one-asset lock shape.

## Exact denominator

- domain activities: `12`;
- generated cells: `12`;
- required promoted patterns: `11`;
- generated files: `7`;
- manifest-covered files: `6`;
- root README readiness authority: `0`;
- source repository writes: `0`;
- local test executions: `0`.

## Adversarial cases

- remove `ObserveSourceSnapshot`: `4 CLOSED + 1 DIRECT_MISSING + 7
  DEPENDENCY_BLOCKED`;
- duplicate `CloseReleaseDecision`: `11 CLOSED + 1 REFUTED`;
- mutate a generated denominator after manifest creation: `5/6 VERIFIED + 1
  REFUTED`.

All three cases must leave generator-pattern promotion at `11` because they
change only the project graph.

## Independence

This consumer pins an immutable generator release asset. The generator does not
query this repository, and this repository does not become a predecessor of
the generator, the other domain projects, or the core compiler.

## Non-claims

Passing generation does not replace the local-ledger readiness decision, prove
runtime behavior, or count as a second independent consumer. This repository is
consumer `1/2` only after its main-branch CI publishes the adoption receipt.
