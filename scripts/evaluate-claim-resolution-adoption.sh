#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 14; then
  echo "usage: evaluate-claim-resolution-adoption.sh GRAPH DENOMINATOR CLOSED UNKNOWN REFUTED INVALID_UNKNOWN INVALID_STATE READY_REPORT UNKNOWN_REPORT REFUTED_REPORT REPLAY OUTPUT SUBJECT_SHA SCENARIO" >&2
  exit 2
fi

graph=$1
denominator=$2
closed_receipt=$3
unknown_receipt=$4
refuted_receipt=$5
invalid_unknown_receipt=$6
invalid_state_receipt=$7
ready_report=$8
unknown_report=$9
refuted_report=${10}
replay=${11}
output=${12}
subject_sha=${13}
scenario=${14}

for file in "$graph" "$denominator" "$closed_receipt" "$unknown_receipt" "$refuted_receipt" "$invalid_unknown_receipt" "$invalid_state_receipt" "$ready_report" "$unknown_report" "$refuted_report" "$replay"; do
  test -f "$file" || { echo "missing required input: $file" >&2; exit 2; }
done

jq -e '
  .schema=="gooo/local-ledger/claim-resolution-adoption-denominator/v1" and
  .candidate_id=="gooo.primitive.claim-resolution-tuple.v1" and
  .total==12 and (.cells|length)==12 and
  ([.cells[].id]|unique|length)==12 and
  ([.cells[].activity]|unique|length)==12 and
  ([.proofs[].total]|add)==12 and ([.indicator_classes[].total]|add)==12
' "$denominator" >/dev/null

jq -e --slurpfile denominator "$denominator" '
  . as $graph |
  .schema_version=="gooo-graph/v1" and
  ([$graph.nodes[]|select(.kind=="Activity")]|length)==12 and
  ([$denominator[0].cells[] as $cell |
    select(([$graph.nodes[]|select(.kind=="Activity" and .name==$cell.activity)]|length)==1)
  ]|length)==12
' "$graph" >/dev/null

validate_receipt() {
  file=$1 activity=$2 state=$3 stage=$4 step=$5 reason=$6 unknown_class=$7 next_operation=$8
  jq -e --arg activity "$activity" --arg state "$state" --arg stage "$stage" --arg step "$step" \
    --arg reason "$reason" --arg unknown_class "$unknown_class" --arg next_operation "$next_operation" '
    .schema=="gooo/claim-resolution/v1" and
    .candidate_id=="gooo.primitive.claim-resolution-tuple.v1" and
    .decision=="CLAIM_RESOLUTION_OBSERVED" and
    .subject.activity==$activity and .subject.activity_occurrences==1 and
    .subject.binding=="GOOO_ACTIVITY_VALUE_PROGRAM" and
    .contract.version=="v1" and (.contract.base_fields|length)==6 and
    .contract.states==["CLOSED","UNKNOWN","REFUTED"] and
    .claim.state==$state and
    .claim.stage==(if $stage=="NONE" then null else $stage end) and
    .claim.step==(if $step=="NONE" then null else $step end) and
    .claim.reason==$reason and
    .claim.unknown_class==(if $unknown_class=="NONE" then null else $unknown_class end) and
    .claim.next_operation==$next_operation and
    .summary.fields_observed==6 and .summary.fields_total==6 and
    .summary.resolutions_observed==1 and .summary.resolutions_total==1 and
    .summary.repository_writes==0 and (.indicators|length)==4 and
    all(.indicators[];.activity==$activity) and
    .authority.source=="GOOO_ACTIVITY_VALUE_PROGRAM" and
    .authority.core_mutation_authorized==false and .authority.repository_writes==0
  ' "$file" >/dev/null
}

validate_invalid_receipt() {
  file=$1 activity=$2 reason=$3 next_operation=$4
  jq -e --arg activity "$activity" --arg reason "$reason" --arg next_operation "$next_operation" '
    .schema=="gooo/claim-resolution/v1" and
    .candidate_id=="gooo.primitive.claim-resolution-tuple.v1" and
    .decision=="FAIL_CLOSED" and .subject.activity==$activity and
    .subject.activity_occurrences==1 and .claim.state=="REFUTED" and
    .claim.stage=="CLAIM_RESOLUTION" and .claim.step=="PARSE_CLAIM_RESOLUTION_TUPLE" and
    .claim.reason==$reason and .claim.unknown_class==null and
    .claim.next_operation==$next_operation and
    .summary.fields_observed==6 and .summary.fields_total==6 and
    .summary.resolutions_observed==0 and .summary.repository_writes==0
  ' "$file" >/dev/null
}

validate_readiness() {
  file=$1 decision=$2 state=$3 stage=$4 step=$5 reason=$6 next_operation=$7
  files=$8 directories=$9 go_lines=${10} gooo_lines=${11} closed=${12} unknown=${13} refuted=${14}
  jq -e --arg decision "$decision" --arg state "$state" --arg stage "$stage" --arg step "$step" \
    --arg reason "$reason" --arg next_operation "$next_operation" --argjson files "$files" \
    --argjson directories "$directories" --argjson go_lines "$go_lines" --argjson gooo_lines "$gooo_lines" \
    --argjson closed "$closed" --argjson unknown "$unknown" --argjson refuted "$refuted" '
    .schema=="gooo/local-ledger/readiness-report/v1" and .decision==$decision and
    .claim.state==$state and .claim.stage==(if $stage=="NONE" then null else $stage end) and
    .claim.step==(if $step=="NONE" then null else $step end) and .claim.reason==$reason and
    .claim.next_operation==$next_operation and (.claim|has("unknown_class")|not) and
    .summary=={total:12,closed:$closed,unknown:$unknown,refuted:$refuted,repository_writes:0} and
    .inventory.files==$files and .inventory.descendant_directories==$directories and
    .inventory.go_physical_lines==$go_lines and .inventory.gooo_physical_lines==$gooo_lines and
    .inventory.required_artifacts_observed==(if $state=="UNKNOWN" then 4 else 5 end) and
    .inventory.required_artifacts_total==5 and
    .authority.activity_bindings==12 and .authority.activity_total==12 and
    .authority.effect=="READ_ONLY" and .authority.external_required_gates==0 and
    .authority.cross_project_branch_inputs==0 and .authority.root_readme_required==false and
    .authority.local_tests_required==0
  ' "$file" >/dev/null
}

compare_released_fields() {
  readiness=$1 receipt=$2
  jq -e --slurpfile receipt "$receipt" '
    (.claim|{state,stage,step,reason,next_operation}) ==
    ($receipt[0].claim|{state,stage,step,reason,next_operation})
  ' "$readiness" >/dev/null
}

validate_valid_receipts() {
  validate_receipt "$closed_receipt" ResolveReleaseReadyClaim CLOSED NONE NONE RELEASE_READINESS_CLOSED NONE NONE
  validate_receipt "$unknown_receipt" ResolveMissingRunbookClaim UNKNOWN OPERATIONS OBSERVE_RUNBOOK OPERATIONS_RUNBOOK_UNAVAILABLE DIRECT_MISSING PROVIDE_OPERATIONS_RUNBOOK
  validate_receipt "$refuted_receipt" ResolveSourceMismatchClaim REFUTED SOURCE VERIFY_SOURCE_SNAPSHOT SOURCE_SNAPSHOT_MISMATCH NONE RESTORE_EXPECTED_SOURCE_SNAPSHOT
}

validate_released_reports() {
  validate_readiness "$ready_report" RELEASE_READY CLOSED NONE NONE RELEASE_READINESS_CLOSED NONE 6 2 7 28 12 0 0
  validate_readiness "$unknown_report" NOT_READY UNKNOWN OPERATIONS OBSERVE_RUNBOOK OPERATIONS_RUNBOOK_UNAVAILABLE PROVIDE_OPERATIONS_RUNBOOK 5 2 7 28 10 2 0
  validate_readiness "$refuted_report" FAIL_CLOSED REFUTED SOURCE VERIFY_SOURCE_SNAPSHOT SOURCE_SNAPSHOT_MISMATCH RESTORE_EXPECTED_SOURCE_SNAPSHOT 6 2 9 28 10 0 2
}

validate_comparisons() {
  compare_released_fields "$ready_report" "$closed_receipt"
  compare_released_fields "$unknown_report" "$unknown_receipt"
  compare_released_fields "$refuted_report" "$refuted_receipt"
}

validate_replay() {
  jq -e '.schema=="gooo/local-ledger/claim-resolution-replay/v1" and .receipts_compared==5 and .receipts_equal==5 and .deterministic==true' "$replay" >/dev/null
}

digest() {
  printf 'sha256:%s' "$(sha256sum "$1" | awk '{print $1}')"
}

case "$scenario" in
  complete)
    validate_valid_receipts
    validate_invalid_receipt "$invalid_unknown_receipt" RejectIncompleteUnknown UNKNOWN_TUPLE_INCOMPLETE PROVIDE_COMPLETE_UNKNOWN_TUPLE
    validate_invalid_receipt "$invalid_state_receipt" RejectUnrecognizedState CLAIM_STATE_UNKNOWN RESTORE_CLOSED_UNKNOWN_OR_REFUTED_STATE
    validate_released_reports
    validate_comparisons
    validate_replay
    ;;
  missing-receipt)
    jq -e '.==null' "$unknown_receipt" >/dev/null
    validate_receipt "$closed_receipt" ResolveReleaseReadyClaim CLOSED NONE NONE RELEASE_READINESS_CLOSED NONE NONE
    validate_receipt "$refuted_receipt" ResolveSourceMismatchClaim REFUTED SOURCE VERIFY_SOURCE_SNAPSHOT SOURCE_SNAPSHOT_MISMATCH NONE RESTORE_EXPECTED_SOURCE_SNAPSHOT
    validate_invalid_receipt "$invalid_unknown_receipt" RejectIncompleteUnknown UNKNOWN_TUPLE_INCOMPLETE PROVIDE_COMPLETE_UNKNOWN_TUPLE
    validate_invalid_receipt "$invalid_state_receipt" RejectUnrecognizedState CLAIM_STATE_UNKNOWN RESTORE_CLOSED_UNKNOWN_OR_REFUTED_STATE
    validate_released_reports
    compare_released_fields "$ready_report" "$closed_receipt"
    compare_released_fields "$refuted_report" "$refuted_receipt"
    validate_replay
    ;;
  local-claim-tamper)
    validate_valid_receipts
    validate_invalid_receipt "$invalid_unknown_receipt" RejectIncompleteUnknown UNKNOWN_TUPLE_INCOMPLETE PROVIDE_COMPLETE_UNKNOWN_TUPLE
    validate_invalid_receipt "$invalid_state_receipt" RejectUnrecognizedState CLAIM_STATE_UNKNOWN RESTORE_CLOSED_UNKNOWN_OR_REFUTED_STATE
    validate_readiness "$ready_report" RELEASE_READY CLOSED NONE NONE RELEASE_READINESS_CLOSED NONE 6 2 7 28 12 0 0
    jq -e '.schema=="gooo/local-ledger/readiness-report/v1" and .claim.state=="UNKNOWN" and .claim.next_operation=="REQUEST_HUMAN_GUESS"' "$unknown_report" >/dev/null
    validate_readiness "$refuted_report" FAIL_CLOSED REFUTED SOURCE VERIFY_SOURCE_SNAPSHOT SOURCE_SNAPSHOT_MISMATCH RESTORE_EXPECTED_SOURCE_SNAPSHOT 6 2 9 28 10 0 2
    compare_released_fields "$ready_report" "$closed_receipt"
    compare_released_fields "$refuted_report" "$refuted_receipt"
    validate_replay
    ;;
  unknown-class-tamper)
    validate_receipt "$closed_receipt" ResolveReleaseReadyClaim CLOSED NONE NONE RELEASE_READINESS_CLOSED NONE NONE
    jq -e '.schema=="gooo/claim-resolution/v1" and .decision=="CLAIM_RESOLUTION_OBSERVED" and .claim.state=="UNKNOWN" and .claim.unknown_class=="CONTEXT_MISSING"' "$unknown_receipt" >/dev/null
    validate_receipt "$refuted_receipt" ResolveSourceMismatchClaim REFUTED SOURCE VERIFY_SOURCE_SNAPSHOT SOURCE_SNAPSHOT_MISMATCH NONE RESTORE_EXPECTED_SOURCE_SNAPSHOT
    validate_invalid_receipt "$invalid_unknown_receipt" RejectIncompleteUnknown UNKNOWN_TUPLE_INCOMPLETE PROVIDE_COMPLETE_UNKNOWN_TUPLE
    validate_invalid_receipt "$invalid_state_receipt" RejectUnrecognizedState CLAIM_STATE_UNKNOWN RESTORE_CLOSED_UNKNOWN_OR_REFUTED_STATE
    validate_released_reports
    validate_comparisons
    validate_replay
    ;;
  invalid-core-decision)
    validate_valid_receipts
    validate_invalid_receipt "$invalid_unknown_receipt" RejectIncompleteUnknown UNKNOWN_TUPLE_INCOMPLETE PROVIDE_COMPLETE_UNKNOWN_TUPLE
    jq -e '.decision=="CLAIM_RESOLUTION_OBSERVED" and .claim.reason=="CLAIM_STATE_UNKNOWN"' "$invalid_state_receipt" >/dev/null
    validate_released_reports
    validate_comparisons
    validate_replay
    ;;
  scope-escalation)
    jq -e '.decision=="CLAIM_RESOLUTION_OBSERVED" and .authority.repository_writes==1' "$closed_receipt" >/dev/null
    validate_receipt "$unknown_receipt" ResolveMissingRunbookClaim UNKNOWN OPERATIONS OBSERVE_RUNBOOK OPERATIONS_RUNBOOK_UNAVAILABLE DIRECT_MISSING PROVIDE_OPERATIONS_RUNBOOK
    validate_receipt "$refuted_receipt" ResolveSourceMismatchClaim REFUTED SOURCE VERIFY_SOURCE_SNAPSHOT SOURCE_SNAPSHOT_MISMATCH NONE RESTORE_EXPECTED_SOURCE_SNAPSHOT
    validate_invalid_receipt "$invalid_unknown_receipt" RejectIncompleteUnknown UNKNOWN_TUPLE_INCOMPLETE PROVIDE_COMPLETE_UNKNOWN_TUPLE
    validate_invalid_receipt "$invalid_state_receipt" RejectUnrecognizedState CLAIM_STATE_UNKNOWN RESTORE_CLOSED_UNKNOWN_OR_REFUTED_STATE
    validate_released_reports
    validate_replay
    ;;
  *)
    echo "unsupported scenario: $scenario" >&2
    exit 2
    ;;
esac

jq -S -n \
  --slurpfile denominator "$denominator" \
  --arg scenario "$scenario" --arg subject_sha "$subject_sha" \
  --arg graph_digest "$(digest "$graph")" --arg denominator_digest "$(digest "$denominator")" \
  --arg closed_digest "$(digest "$closed_receipt")" --arg unknown_digest "$(digest "$unknown_receipt")" \
  --arg refuted_digest "$(digest "$refuted_receipt")" \
  --arg invalid_unknown_digest "$(digest "$invalid_unknown_receipt")" \
  --arg invalid_state_digest "$(digest "$invalid_state_receipt")" \
  --arg ready_digest "$(digest "$ready_report")" --arg released_unknown_digest "$(digest "$unknown_report")" \
  --arg released_refuted_digest "$(digest "$refuted_report")" --arg replay_digest "$(digest "$replay")" '
  $denominator[0] as $d |
  [$d.cells[] |
    {id,activity,proof_choice,indicator_class,state:"CLOSED",stage:null,step:null,
      reason:.closed_reason,unknown_class:null,next_operation:"NONE",blocked_by:[]} |
    if $scenario=="missing-receipt" and .id=="MISSING_RUNBOOK_UNKNOWN_RESOLVED" then
      .+{state:"UNKNOWN",stage:"CORE_RECEIPT",step:"RESOLVE_MISSING_RUNBOOK_CLAIM",
        reason:"CORE_CLAIM_RESOLUTION_RECEIPT_UNAVAILABLE",unknown_class:"DIRECT_MISSING",
        next_operation:"PROVIDE_CORE_CLAIM_RESOLUTION_RECEIPT",blocked_by:["ResolveMissingRunbookClaim"]}
    elif $scenario=="missing-receipt" and (.id=="RELEASED_CLAIMS_COMPARED" or .id=="INDEPENDENT_ADOPTION_RECORDED") then
      .+{state:"UNKNOWN",stage:"DEPENDENCY",step:.activity,reason:"DEPENDENCY_BLOCKED",
        unknown_class:"DEPENDENCY_BLOCKED",next_operation:"RESOLVE_CORE_CLAIM_RECEIPT",
        blocked_by:["MISSING_RUNBOOK_UNKNOWN_RESOLVED"]}
    elif $scenario=="local-claim-tamper" and .id=="RELEASED_CLAIMS_COMPARED" then
      .+{state:"REFUTED",stage:"CLAIM_COMPARISON",step:"COMPARE_RELEASED_AND_CORE_CLAIMS",
        reason:"LOCAL_CORE_CLAIM_MISMATCH",next_operation:"RESTORE_RELEASED_READINESS_CLAIM_FIELDS",
        blocked_by:["missing-runbook.json"]}
    elif $scenario=="unknown-class-tamper" and .id=="UNKNOWN_CLASS_BOUND" then
      .+{state:"REFUTED",stage:"UNKNOWN_CLASS",step:"BIND_UNKNOWN_CLASS",
        reason:"UNKNOWN_CLASS_BINDING_MISMATCH",next_operation:"RESTORE_DIRECT_MISSING_UNKNOWN_CLASS",
        blocked_by:["ResolveMissingRunbookClaim"]}
    elif $scenario=="invalid-core-decision" and .id=="UNRECOGNIZED_STATE_REJECTED" then
      .+{state:"REFUTED",stage:"CORE_DECISION",step:"REJECT_UNRECOGNIZED_STATE",
        reason:"INVALID_CORE_CLAIM_DECISION",next_operation:"RESTORE_FAIL_CLOSED_CORE_DECISION",
        blocked_by:["RejectUnrecognizedState"]}
    elif $scenario=="scope-escalation" and .id=="INDEPENDENT_ADOPTION_RECORDED" then
      .+{state:"REFUTED",stage:"AUTHORITY",step:"RECORD_INDEPENDENT_ADOPTION",
        reason:"CORE_REPOSITORY_WRITE_AUTHORITY_ESCALATION",next_operation:"RESTORE_READ_ONLY_CORE_AUTHORITY",
        blocked_by:["ResolveReleaseReadyClaim"]}
    else . end
  ] as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed_count |
  ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown_count |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted_count |
  (([$cells[]|select(.state=="REFUTED")][0]) // ([$cells[]|select(.state=="UNKNOWN")][0])) as $first |
  (if $scenario=="missing-receipt" then 2 else 3 end) as $resolved_scenarios |
  (if $scenario=="missing-receipt" or $scenario=="local-claim-tamper" then 2 else 3 end) as $matched_claims |
  (if $scenario=="missing-receipt" then 10 elif $scenario=="local-claim-tamper" then 14 else 15 end) as $released_fields |
  (if $scenario=="missing-receipt" then 12 else 18 end) as $core_fields |
  (if $scenario=="missing-receipt" or $scenario=="unknown-class-tamper" then 0 else 1 end) as $unknown_bindings |
  (if $scenario=="invalid-core-decision" then 1 else 2 end) as $rejections |
  {
    schema:"gooo/local-ledger/claim-resolution-adoption-report/v1",
    scenario:$scenario,subject_sha:$subject_sha,
    decision:(if $refuted_count>0 then "FAIL_CLOSED" elif $unknown_count>0 then "CLAIM_RESOLUTION_ADOPTION_UNKNOWN" else "CLAIM_RESOLUTION_ADOPTION_OBSERVED" end),
    candidate:{id:$d.candidate_id,state:(if $refuted_count>0 then "REFUTED" elif $unknown_count>0 then "UNKNOWN" else "ADOPTED" end),
      implementation_status:(if $scenario=="complete" then "INDEPENDENT_CONSUMER_ADOPTION_OBSERVED" else "NOT_COUNTED" end)},
    claim:(if $first==null then
      {state:"CLOSED",stage:null,step:null,reason:"LOCAL_LEDGER_CLAIM_RESOLUTION_ADOPTION_OBSERVED",
        unknown_class:null,next_operation:"PUBLISH_LOCAL_CLAIM_RESOLUTION_ADOPTION",blocked_by:[]}
      else {state:$first.state,stage:$first.stage,step:$first.step,reason:$first.reason,
        unknown_class:$first.unknown_class,next_operation:$first.next_operation,blocked_by:$first.blocked_by} end),
    summary:{total_cells:12,closed_cells:$closed_count,unknown_cells:$unknown_count,refuted_cells:$refuted_count,
      claim_scenarios_total:3,claim_scenarios_resolved:$resolved_scenarios,
      released_claims_total:3,released_claims_matched:$matched_claims,
      released_claim_fields_total:15,released_claim_fields_matched:$released_fields,
      core_claim_fields_total:18,core_claim_fields_observed:$core_fields,
      unknown_class_bindings_total:1,unknown_class_bindings_observed:$unknown_bindings,
      rejection_scenarios_total:2,rejection_scenarios_observed:$rejections,
      inventory_facts_total:4,inventory_facts_observed:4,
      independent_consumer_adoptions:(if $scenario=="complete" then 1 else 0 end),
      repository_writes:0,local_tests_run:0,cross_project_required_gates:0},
    inventory:{files:6,descendant_directories:2,go_physical_lines:7,gooo_physical_lines:28},
    authority:{core_release:"v0.3.0-dev",readiness_release:"v0.5.0-dev",
      resolution_source:"GOOO_ACTIVITY_VALUE_PROGRAM",released_claim_schema:"gooo/local-ledger/readiness-report/v1",
      released_claim_fields_per_scenario:5,unknown_class_binding:"EXPLICIT_GOOO_ACTIVITY_VALUE",
      core_mutation_authorized:false,dependency_propagation_authorized:false,automatic_merge_authorized:false,
      root_readme_readiness:"EXCLUDED"},
    evidence:{graph_digest:$graph_digest,denominator_digest:$denominator_digest,
      closed_digest:$closed_digest,unknown_digest:$unknown_digest,refuted_digest:$refuted_digest,
      invalid_unknown_digest:$invalid_unknown_digest,invalid_state_digest:$invalid_state_digest,
      ready_digest:$ready_digest,released_unknown_digest:$released_unknown_digest,
      released_refuted_digest:$released_refuted_digest,replay_digest:$replay_digest},
    cells:$cells,
    proofs:[$d.proofs[] as $proof | {choice:$proof.choice,total:$proof.total,
      closed:([$cells[]|select(.proof_choice==$proof.choice and .state=="CLOSED")]|length)}],
    indicator_classes:[$d.indicator_classes[] as $indicator | {class:$indicator.class,total:$indicator.total,
      closed:([$cells[]|select(.indicator_class==$indicator.class and .state=="CLOSED")]|length)}]
  }
' > "$output"
