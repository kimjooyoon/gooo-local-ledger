#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 8 ]; then
  echo "usage: project-semantic-plan.sh GOOO PROJECT MISSING UNSUPPORTED AMBIGUOUS CYCLE CONTRACT OUTPUT_DIR" >&2
  exit 64
fi

gooo=$1
project=$2
missing=$3
unsupported=$4
ambiguous=$5
cycle=$6
contract=$7
output=$8

for required in "$gooo" "$project" "$missing" "$unsupported" "$ambiguous" "$cycle" "$contract"; do
  if [ ! -f "$required" ]; then
    echo "required input unavailable: $required" >&2
    exit 66
  fi
done

mkdir -p "$output/evidence"
closed_receipt="$output/evidence/closed.json"
missing_receipt="$output/evidence/missing-producer.json"
unsupported_receipt="$output/evidence/unsupported-kind.json"
ambiguous_receipt="$output/evidence/ambiguous-producer.json"
cycle_receipt="$output/evidence/cycle.json"

report_failure() {
  status=$?
  if [ "$status" -ne 0 ]; then
    echo "semantic project plan generation failed with status $status" >&2
    for receipt in "$closed_receipt" "$missing_receipt" "$unsupported_receipt" "$ambiguous_receipt" "$cycle_receipt"; do
      if [ -s "$receipt" ]; then
        echo "=== $receipt ===" >&2
        cat "$receipt" >&2
      fi
    done
  fi
}
trap report_failure EXIT

"$gooo" claim dependencies "$project" --json > "$closed_receipt"

run_nonclosed() {
  source_file=$1
  receipt_file=$2
  set +e
  "$gooo" claim dependencies "$source_file" --json > "$receipt_file"
  command_status=$?
  set -e
  if [ "$command_status" -eq 0 ]; then
    echo "non-closed fixture was accepted: $source_file" >&2
    exit 65
  fi
}

run_nonclosed "$missing" "$missing_receipt"
run_nonclosed "$unsupported" "$unsupported_receipt"
run_nonclosed "$ambiguous" "$ambiguous_receipt"
run_nonclosed "$cycle" "$cycle_receipt"

jq -e --slurpfile contract "$contract" '
  .schema=="gooo/claim-dependency-causality/v1" and
  .candidate_id==$contract[0].primitive.id and
  .decision=="CLAIM_DEPENDENCY_OBSERVED" and
  .resolution.state=="CLOSED" and
  .resolution.reason=="CLAIM_DEPENDENCY_CAUSALITY_OBSERVED" and
  .summary.activities_total==$contract[0].normal.activities and
  .summary.activities_observed==$contract[0].normal.activities and
  .summary.recoverable_roots==$contract[0].normal.recoverable_roots and
  .summary.typed_declarations==$contract[0].normal.typed_declarations and
  .summary.dependency_inputs==$contract[0].normal.dependency_inputs and
  .summary.typed_edges==$contract[0].normal.dependencies and
  .summary.edge_kinds_observed==$contract[0].normal.edge_kinds and
  .summary.unresolved_inputs==0 and
  .summary.cyclic_activities==0 and
  .summary.repository_writes==0 and
  .kind_counts==$contract[0].normal.kind_counts and
  ([.nodes[].activity]==$contract[0].activity_order) and
  (.nodes|length)==$contract[0].normal.activities and
  (.edges|length)==$contract[0].normal.dependencies and
  (.gaps|length)==0 and
  (.indicators|length)==8 and
  all(.indicators[];
    if .comparator=="EQ" then .value==.target
    elif .comparator=="GTE" then .value>=.target
    elif .comparator=="LTE" then .value<=.target
    else false end) and
  .authority.semantic_truth_claimed==false and
  .authority.state_propagation_authorized==false and
  .authority.core_mutation_authorized==false and
  .authority.automatic_merge_allowed==false and
  .authority.repository_writes==0
' "$closed_receipt" >/dev/null

jq -e --slurpfile contract "$contract" '
  .schema=="gooo/claim-dependency-causality/v1" and
  .decision==$contract[0].unknown.decision and
  .resolution.state==$contract[0].unknown.state and
  .resolution.stage==$contract[0].unknown.stage and
  .resolution.step==$contract[0].unknown.step and
  .resolution.reason==$contract[0].unknown.reason and
  .resolution.unknown_class==$contract[0].unknown.unknown_class and
  .resolution.next_operation==$contract[0].unknown.next_operation and
  (.resolution.blocked_by|length)==$contract[0].unknown.blocked_by and
  .summary.unresolved_inputs==1
' "$missing_receipt" >/dev/null

jq -e --arg reason "CLAIM_DEPENDENCY_EDGE_KIND_UNSUPPORTED" '
  .schema=="gooo/claim-dependency-causality/v1" and .decision=="FAIL_CLOSED" and
  .resolution.state=="REFUTED" and .resolution.reason==$reason
' "$unsupported_receipt" >/dev/null
jq -e --arg reason "CLAIM_OUTPUT_PRODUCER_AMBIGUOUS" '
  .schema=="gooo/claim-dependency-causality/v1" and .decision=="FAIL_CLOSED" and
  .resolution.state=="REFUTED" and .resolution.reason==$reason
' "$ambiguous_receipt" >/dev/null
jq -e --arg reason "CLAIM_DEPENDENCY_CYCLE_DETECTED" '
  .schema=="gooo/claim-dependency-causality/v1" and .decision=="FAIL_CLOSED" and
  .resolution.state=="REFUTED" and .resolution.reason==$reason
' "$cycle_receipt" >/dev/null

source_sha=$(sha256sum "$project" | awk '{print $1}')

jq -S -n \
  --slurpfile contract "$contract" \
  --slurpfile closed "$closed_receipt" \
  --slurpfile missing "$missing_receipt" \
  --slurpfile unsupported "$unsupported_receipt" \
  --slurpfile ambiguous "$ambiguous_receipt" \
  --slurpfile cycle "$cycle_receipt" \
  --arg source_sha "$source_sha" '
  {
    schema:"gooo/local-ledger/semantic-project-plan/v1",
    decision:"PROJECT_PLAN_PACKET_GENERATED",
    project:{
      id:$contract[0].project.id,
      name:$contract[0].project.name,
      source_path:$contract[0].project.source_path,
      source_sha256:$source_sha
    },
    primitive:$contract[0].primitive,
    semantics:{
      scope:"STRUCTURAL_DEPENDENCY_ONLY",
      conformance_state:$closed[0].resolution.state,
      conformance_reason:$closed[0].resolution.reason
    },
    summary:{
      activities:$closed[0].summary.activities_observed,
      recoverable_roots:$closed[0].summary.recoverable_roots,
      dependencies:$closed[0].summary.typed_edges,
      dependency_kinds:$closed[0].summary.edge_kinds_observed,
      generated_artifacts:2,
      unknown_coordinates:$contract[0].unknown.coordinates,
      refuted_boundaries:($contract[0].refutations|length)
    },
    kind_counts:$closed[0].kind_counts,
    steps:[$closed[0].nodes[]|{
      ordinal,activity,output_entity,role,label,proof_choice,value_program_digest
    }],
    dependencies:[$closed[0].edges[]|{
      ordinal,id,kind,label,from_activity,to_activity,via_entity
    }],
    recovery:{
      decision:$missing[0].decision,
      state:$missing[0].resolution.state,
      stage:$missing[0].resolution.stage,
      step:$missing[0].resolution.step,
      reason:$missing[0].resolution.reason,
      unknown_class:$missing[0].resolution.unknown_class,
      next_operation:$missing[0].resolution.next_operation,
      blocked_by:$missing[0].resolution.blocked_by
    },
    refutation_boundaries:[
      {case:"unsupported-kind",reason:$unsupported[0].resolution.reason,state:$unsupported[0].resolution.state},
      {case:"ambiguous-producer",reason:$ambiguous[0].resolution.reason,state:$ambiguous[0].resolution.state},
      {case:"cycle",reason:$cycle[0].resolution.reason,state:$cycle[0].resolution.state}
    ],
    non_claims:$contract[0].non_claims,
    authority:{
      repository_mutation_authorized:false,
      automatic_repair_authorized:false,
      automatic_merge_allowed:false,
      semantic_truth_claimed:false,
      state_propagation_authorized:false,
      cross_project_authority:false,
      repository_writes:0
    }
  }
' > "$output/project-plan.json"

{
  echo "# Semantic project plan"
  echo
  jq -r '"Project: **\(.project.name)**  \nProject ID: \(.project.id)  \nDecision: \(.decision)  \nScope: \(.semantics.scope)"' "$output/project-plan.json"
  echo
  echo "## Exact counts"
  echo
  jq -r '"- Activities: \(.summary.activities)/6\n- Dependencies: \(.summary.dependencies)/8\n- Dependency kinds: \(.summary.dependency_kinds)/4\n- Generated artifacts: \(.summary.generated_artifacts)/2\n- UNKNOWN coordinates: \(.summary.unknown_coordinates)/6\n- REFUTED boundaries: \(.summary.refuted_boundaries)/3"' "$output/project-plan.json"
  echo
  echo "## Work steps"
  echo
  jq -r '.steps[] | "- \(.ordinal). \(.activity): \(.label) -> \(.output_entity)"' "$output/project-plan.json"
  echo
  echo "## Structural dependencies"
  echo
  jq -r '.dependencies[] | "- \(.id): \(.from_activity) --\(.kind) via \(.via_entity)--> \(.to_activity) [\(.label)]"' "$output/project-plan.json"
  echo
  echo "## UNKNOWN recovery"
  echo
  jq -r '"- Stage: \(.recovery.stage)\n- Step: \(.recovery.step)\n- Reason: \(.recovery.reason)\n- Class: \(.recovery.unknown_class)\n- Next operation: \(.recovery.next_operation)\n- Blocked by: \(.recovery.blocked_by | join(", "))"' "$output/project-plan.json"
  echo
  echo "## REFUTED boundaries"
  echo
  jq -r '.refutation_boundaries[] | "- \(.case): \(.state) / \(.reason)"' "$output/project-plan.json"
  echo
  echo "## Non-claims"
  echo
  jq -r '.non_claims[] | "- \(.)"' "$output/project-plan.json"
} > "$output/project-plan.md"
