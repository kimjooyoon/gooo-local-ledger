#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 8; then
  echo "usage: evaluate-readiness-claim-projection.sh GRAPH DENOMINATOR CLASSIFICATION EVIDENCE_DIR RUNTIME OUTPUT SUBJECT_SHA PHASE" >&2
  exit 2
fi

graph=$1
denominator=$2
classification=$3
evidence=$4
runtime=$5
output=$6
subject_sha=$7
phase=$8

ready_report="$evidence/reports/ready.json"
unknown_report="$evidence/reports/missing-runbook.json"
refuted_report="$evidence/reports/source-refuted.json"
ready_projection="$evidence/projected/ready/projection.json"
unknown_projection="$evidence/projected/missing-runbook/projection.json"
refuted_projection="$evidence/projected/source-refuted/projection.json"
ready_receipt="$evidence/receipts/ready.json"
unknown_receipt="$evidence/receipts/missing-runbook.json"
refuted_receipt="$evidence/receipts/source-refuted.json"
undeclared_counterexample="$evidence/counterexamples/undeclared.json"
duplicate_counterexample="$evidence/counterexamples/duplicate.json"
replay="$evidence/replay.json"

for file in "$graph" "$denominator" "$classification" "$runtime" \
  "$ready_report" "$unknown_report" "$refuted_report" \
  "$ready_projection" "$unknown_projection" "$refuted_projection" \
  "$ready_receipt" "$unknown_receipt" "$refuted_receipt" \
  "$undeclared_counterexample" "$duplicate_counterexample" "$replay"; do
  test -f "$file" || { echo "missing projection evidence: $file" >&2; exit 2; }
done

jq -S -n \
  --slurpfile graph "$graph" \
  --slurpfile denominator "$denominator" \
  --slurpfile classification "$classification" \
  --slurpfile runtime "$runtime" \
  --slurpfile ready_report "$ready_report" \
  --slurpfile unknown_report "$unknown_report" \
  --slurpfile refuted_report "$refuted_report" \
  --slurpfile ready_projection "$ready_projection" \
  --slurpfile unknown_projection "$unknown_projection" \
  --slurpfile refuted_projection "$refuted_projection" \
  --slurpfile ready_receipt "$ready_receipt" \
  --slurpfile unknown_receipt "$unknown_receipt" \
  --slurpfile refuted_receipt "$refuted_receipt" \
  --slurpfile undeclared "$undeclared_counterexample" \
  --slurpfile duplicate "$duplicate_counterexample" \
  --slurpfile replay "$replay" \
  --arg subject_sha "$subject_sha" --arg phase "$phase" '
  def cell($id): $denominator[0].cells[] | select(.id==$id);
  def clean: del(.closed_reason,.unknown_reason,.refuted_reason,.repair_operation,.depends_on);
  def closed($cell): ($cell + {state:"CLOSED",reason:$cell.closed_reason,unknown_class:null,next_operation:"NONE",blocked_by:[]}) | clean;
  def unknown_direct($cell;$reason;$next): ($cell + {state:"UNKNOWN",reason:$reason,unknown_class:"DIRECT_MISSING",next_operation:$next,blocked_by:[]}) | clean;
  def unknown_dependency($cell;$blocked): ($cell + {state:"UNKNOWN",reason:"DEPENDENCY_EVIDENCE_UNAVAILABLE",unknown_class:"DEPENDENCY_BLOCKED",next_operation:"RESOLVE_BLOCKING_CLAIMS",blocked_by:$blocked}) | clean;
  def refuted_direct($cell;$reason;$next): ($cell + {state:"REFUTED",reason:$reason,unknown_class:null,next_operation:$next,blocked_by:[]}) | clean;
  def refuted_dependency($cell;$blocked): ($cell + {state:"REFUTED",reason:"DEPENDENCY_REFUTED",unknown_class:null,next_operation:"RESOLVE_BLOCKING_REFUTATIONS",blocked_by:$blocked}) | clean;
  def with_dependencies($cell;$deps;$direct):
    ([$deps[]|select(.state=="REFUTED")|.id]) as $refuted |
    ([$deps[]|select(.state=="UNKNOWN")|.id]) as $unknown |
    if ($refuted|length)>0 then refuted_dependency($cell;$refuted)
    elif ($unknown|length)>0 then unknown_dependency($cell;$unknown)
    else $direct end;
  def projection_available($projection):
    ($projection|type)=="object" and $projection.schema=="gooo/local-ledger/readiness-claim-projection/v1" and
    $projection.decision=="READINESS_CLAIM_PROGRAM_PROJECTED" and $projection.generated_claim_programs==1 and
    $projection.projected_tuple_fields==6;
  def receipt_available($receipt):
    ($receipt|type)=="object" and $receipt.schema=="gooo/claim-resolution/v1" and
    $receipt.decision=="CLAIM_RESOLUTION_OBSERVED" and ($receipt.claim|type)=="object";
  def source_projection_match($report;$projection):
    projection_available($projection) and
    $projection.claim.state==$report.claim.state and $projection.claim.stage==$report.claim.stage and
    $projection.claim.step==$report.claim.step and $projection.claim.reason==$report.claim.reason and
    $projection.claim.next_operation==$report.claim.next_operation and
    (if $report.claim.state=="UNKNOWN" then $projection.claim.unknown_class=="DIRECT_MISSING" else $projection.claim.unknown_class==null end);
  def tuple_match($report;$projection;$receipt):
    source_projection_match($report;$projection) and receipt_available($receipt) and
    $receipt.claim.state==$projection.claim.state and $receipt.claim.stage==$projection.claim.stage and
    $receipt.claim.step==$projection.claim.step and $receipt.claim.reason==$projection.claim.reason and
    $receipt.claim.unknown_class==$projection.claim.unknown_class and
    $receipt.claim.next_operation==$projection.claim.next_operation;
  def counterexample_ok($counterexample;$reason):
    ($counterexample|type)=="object" and $counterexample.decision=="FAIL_CLOSED" and
    $counterexample.claim.state=="REFUTED" and $counterexample.claim.reason==$reason;
  ([ $denominator[0].cells[].activity ]|sort) as $expected_activities |
  ([ $graph[0].nodes[]? | select(.kind=="Activity") | .name ]|sort) as $actual_activities |
  ($denominator[0].schema=="gooo/local-ledger/readiness-claim-projection-denominator/v1" and
    $denominator[0].target_cells==12 and ($denominator[0].cells|length)==12 and
    ([$denominator[0].cells[].id]|unique|length)==12 and
    $actual_activities==$expected_activities and
    ([$denominator[0].cells[]|select(.proof_choice=="FOUNDATION")]|length)==4 and
    ([$denominator[0].cells[]|select(.proof_choice=="COHERENCE")]|length)==4 and
    ([$denominator[0].cells[]|select(.proof_choice=="REGRESSION")]|length)==4 and
    ([$denominator[0].cells[]|select(.indicator_class=="DRIVER")]|length)==4 and
    ([$denominator[0].cells[]|select(.indicator_class=="OUTCOME")]|length)==4 and
    ([$denominator[0].cells[]|select(.indicator_class=="GUARDRAIL")]|length)==4) as $denominator_ok |
  ($classification[0].schema=="gooo/local-ledger/readiness-unknown-classification/v1" and
    $classification[0].source_denominator_id=="gooo://denominator/local-ledger-release-readiness-v1" and
    $classification[0].total==12 and ($classification[0].classes|length)==12 and
    ([$classification[0].classes[].id]|unique|length)==12 and
    ([$classification[0].classes[]|[.stage,.step,.reason,.next_operation]|join("|")]|unique|length)==12) as $classification_ok |
  tuple_match($ready_report[0];$ready_projection[0];$ready_receipt[0]) as $ready_match |
  tuple_match($unknown_report[0];$unknown_projection[0];$unknown_receipt[0]) as $unknown_match |
  tuple_match($refuted_report[0];$refuted_projection[0];$refuted_receipt[0]) as $refuted_match |
  (if $runtime[0].core_release_observed==true then closed(cell("CORE_RELEASE")) else unknown_direct(cell("CORE_RELEASE");"CLAIM_RESOLUTION_CORE_RELEASE_UNAVAILABLE";"PROVIDE_CLAIM_RESOLUTION_CORE_RELEASE") end) as $c1 |
  (if $runtime[0].readiness_release_observed==true then closed(cell("READINESS_RELEASE")) else unknown_direct(cell("READINESS_RELEASE");"RELEASED_READINESS_REPORTS_UNAVAILABLE";"PROVIDE_RELEASED_READINESS_REPORTS") end) as $c2 |
  (if $denominator_ok then closed(cell("READINESS_DENOMINATOR")) else refuted_direct(cell("READINESS_DENOMINATOR");"READINESS_DENOMINATOR_MISMATCH";"RESTORE_READINESS_DENOMINATOR") end) as $c3 |
  (if $classification_ok then closed(cell("UNKNOWN_CLASSIFICATION")) else refuted_direct(cell("UNKNOWN_CLASSIFICATION");"UNKNOWN_CLASSIFICATION_MISMATCH";"RESTORE_UNKNOWN_CLASSIFICATION") end) as $direct4 |
  with_dependencies(cell("UNKNOWN_CLASSIFICATION");[$c3];$direct4) as $c4 |
  (if ((projection_available($ready_projection[0]) and receipt_available($ready_receipt[0])) | not) then unknown_direct(cell("CLOSED_CLAIM_RECEIPT");"PROJECTED_CLOSED_CLAIM_RECEIPT_UNAVAILABLE";"RESOLVE_CLOSED_READINESS_CLAIM")
    elif $ready_match then closed(cell("CLOSED_CLAIM_RECEIPT")) else refuted_direct(cell("CLOSED_CLAIM_RECEIPT");"PROJECTED_CLOSED_CLAIM_TUPLE_MISMATCH";"RESTORE_CLOSED_CLAIM_PROJECTION") end) as $direct5 |
  with_dependencies(cell("CLOSED_CLAIM_RECEIPT");[$c1,$c2,$c3,$c4];$direct5) as $c5 |
  (if ((projection_available($unknown_projection[0]) and receipt_available($unknown_receipt[0])) | not) then unknown_direct(cell("UNKNOWN_CLAIM_RECEIPT");"PROJECTED_UNKNOWN_CLAIM_RECEIPT_UNAVAILABLE";"RESOLVE_UNKNOWN_READINESS_CLAIM")
    elif $unknown_match then closed(cell("UNKNOWN_CLAIM_RECEIPT")) else refuted_direct(cell("UNKNOWN_CLAIM_RECEIPT");"PROJECTED_UNKNOWN_CLAIM_TUPLE_MISMATCH";"RESTORE_UNKNOWN_CLAIM_PROJECTION") end) as $direct6 |
  with_dependencies(cell("UNKNOWN_CLAIM_RECEIPT");[$c1,$c2,$c3,$c4];$direct6) as $c6 |
  (if ((projection_available($refuted_projection[0]) and receipt_available($refuted_receipt[0])) | not) then unknown_direct(cell("REFUTED_CLAIM_RECEIPT");"PROJECTED_REFUTED_CLAIM_RECEIPT_UNAVAILABLE";"RESOLVE_REFUTED_READINESS_CLAIM")
    elif $refuted_match then closed(cell("REFUTED_CLAIM_RECEIPT")) else refuted_direct(cell("REFUTED_CLAIM_RECEIPT");"PROJECTED_REFUTED_CLAIM_TUPLE_MISMATCH";"RESTORE_REFUTED_CLAIM_PROJECTION") end) as $direct7 |
  with_dependencies(cell("REFUTED_CLAIM_RECEIPT");[$c1,$c2,$c3,$c4];$direct7) as $c7 |
  with_dependencies(cell("CLAIM_COMPARISON");[$c5,$c6,$c7];closed(cell("CLAIM_COMPARISON"))) as $c8 |
  (if counterexample_ok($undeclared[0];"UNKNOWN_COORDINATE_UNDECLARED") then closed(cell("UNDECLARED_COORDINATE_REJECTION")) else refuted_direct(cell("UNDECLARED_COORDINATE_REJECTION");"UNDECLARED_UNKNOWN_COORDINATE_ACCEPTED";"RESTORE_UNDECLARED_COORDINATE_REJECTION") end) as $direct9 |
  with_dependencies(cell("UNDECLARED_COORDINATE_REJECTION");[$c3,$c4];$direct9) as $c9 |
  (if counterexample_ok($duplicate[0];"UNKNOWN_CLASSIFICATION_COORDINATE_DUPLICATED") then closed(cell("DUPLICATE_COORDINATE_REJECTION")) else refuted_direct(cell("DUPLICATE_COORDINATE_REJECTION");"DUPLICATE_UNKNOWN_COORDINATE_ACCEPTED";"RESTORE_DUPLICATE_COORDINATE_REJECTION") end) as $direct10 |
  with_dependencies(cell("DUPLICATE_COORDINATE_REJECTION");[$c3,$c4];$direct10) as $c10 |
  (if $replay[0].comparisons_total==9 and $replay[0].comparisons_equal==9 and $replay[0].deterministic==true then closed(cell("PROJECTION_REPLAY")) else refuted_direct(cell("PROJECTION_REPLAY");"PROJECTION_REPLAY_MISMATCH";"RESTORE_DETERMINISTIC_PROJECTION") end) as $direct11 |
  with_dependencies(cell("PROJECTION_REPLAY");[$c5,$c6,$c7,$c8];$direct11) as $c11 |
  with_dependencies(cell("USER_RECEIPT");[$c1,$c2,$c3,$c4,$c5,$c6,$c7,$c8,$c9,$c10,$c11];closed(cell("USER_RECEIPT"))) as $c12 |
  [$c1,$c2,$c3,$c4,$c5,$c6,$c7,$c8,$c9,$c10,$c11,$c12] as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed_count |
  ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown_count |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted_count |
  ([$cells[]|select(.state!="CLOSED")][0] // null) as $first |
  ([$ready_report[0],$unknown_report[0],$refuted_report[0]]|map(select(.schema=="gooo/local-ledger/readiness-report/v1"))|length) as $source_reports |
  ([$ready_projection[0],$unknown_projection[0],$refuted_projection[0]]|map(select(projection_available(.)))|length) as $projected_programs |
  ([$ready_match,$unknown_match,$refuted_match]|map(select(.==true))|length) as $matched_receipts |
  ([(counterexample_ok($undeclared[0];"UNKNOWN_COORDINATE_UNDECLARED")),(counterexample_ok($duplicate[0];"UNKNOWN_CLASSIFICATION_COORDINATE_DUPLICATED"))]|map(select(.==true))|length) as $counterexamples |
  {
    schema:"gooo/local-ledger/readiness-claim-projection-report/v1",phase:$phase,subject_sha:$subject_sha,
    decision:(if $refuted_count>0 then "FAIL_CLOSED" elif $unknown_count>0 then "READINESS_CLAIM_PROJECTION_UNKNOWN" else "READINESS_CLAIM_PROJECTION_OBSERVED" end),
    claim:(if $first==null then {state:"CLOSED",stage:null,step:null,reason:"READINESS_CLAIM_PROJECTION_CLOSED",unknown_class:null,next_operation:"PUBLISH_READINESS_CLAIM_PROJECTION",blocked_by:[]}
      else {state:$first.state,stage:$first.stage,step:$first.step,reason:$first.reason,unknown_class:$first.unknown_class,next_operation:$first.next_operation,blocked_by:$first.blocked_by} end),
    summary:{total_cells:12,closed_cells:$closed_count,unknown_cells:$unknown_count,refuted_cells:$refuted_count,
      source_readiness_reports_observed:$source_reports,source_readiness_reports_total:3,
      source_claim_fields_observed:($source_reports*5),source_claim_fields_total:15,
      projected_claim_programs_observed:$projected_programs,projected_claim_programs_total:3,
      projected_claim_receipts_observed:$matched_receipts,projected_claim_receipts_total:3,
      projected_claim_fields_observed:($matched_receipts*6),projected_claim_fields_total:18,
      unknown_class_bindings_observed:(if $unknown_match then 1 else 0 end),unknown_class_bindings_total:1,
      classification_entries_observed:(if $classification_ok then 12 else 0 end),classification_entries_total:12,
      projection_counterexamples_rejected:$counterexamples,projection_counterexamples_total:2,
      replay_comparisons_equal:$replay[0].comparisons_equal,replay_comparisons_total:9,
      repository_writes:$runtime[0].repository_writes,local_tests_run:$runtime[0].local_tests_run,
      cross_project_required_gates:$runtime[0].cross_project_required_gates},
    inventory:$runtime[0].inventory,performance:$runtime[0].performance,
    authority:{effect:"READ_ONLY",resolution_source:"GENERATED_GOOO_ACTIVITY_VALUE_PROGRAM",
      projection_output_location:"EXTERNAL_TEMPORARY_DIRECTORY",release_locks_observed:$runtime[0].release_locks_observed,
      release_locks_total:2,go_version:$runtime[0].go_version,go_fix_module_roots:$runtime[0].go_fix_module_roots,
      root_readme_readiness:"EXCLUDED",common_generator_authorized:false,central_orchestration_authorized:false},
    cells:$cells,
    proofs:(["FOUNDATION","COHERENCE","REGRESSION"]|map(. as $proof|{choice:$proof,closed:([$cells[]|select(.proof_choice==$proof and .state=="CLOSED")]|length),total:4})),
    indicator_classes:(["DRIVER","OUTCOME","GUARDRAIL"]|map(. as $class|{class:$class,closed:([$cells[]|select(.indicator_class==$class and .state=="CLOSED")]|length),total:4})),
    indicators:[
      {id:"gooo.metric.local-ledger.projection.cells.v1",value:$closed_count,total:12,unit:"cells",activity:"PublishReadinessResolutionReceipt"},
      {id:"gooo.metric.local-ledger.projection.source-reports.v1",value:$source_reports,total:3,unit:"reports",activity:"ObserveReleasedReadinessReports"},
      {id:"gooo.metric.local-ledger.projection.classifications.v1",value:(if $classification_ok then 12 else 0 end),total:12,unit:"classifications",activity:"BindDeclaredUnknownClassifications"},
      {id:"gooo.metric.local-ledger.projection.programs.v1",value:$projected_programs,total:3,unit:"gooo_programs",activity:"ProjectUnknownReadinessClaim"},
      {id:"gooo.metric.local-ledger.projection.receipts.v1",value:$matched_receipts,total:3,unit:"receipts",activity:"CompareProjectedClaimReceipts"},
      {id:"gooo.metric.local-ledger.projection.claim-fields.v1",value:($matched_receipts*6),total:18,unit:"fields",activity:"CompareProjectedClaimReceipts"},
      {id:"gooo.metric.local-ledger.projection.counterexamples.v1",value:$counterexamples,total:2,unit:"counterexamples",activity:"RejectDuplicateUnknownCoordinate"},
      {id:"gooo.metric.local-ledger.projection.replay.v1",value:$replay[0].comparisons_equal,total:9,unit:"comparisons",activity:"ObserveProjectionReplay"},
      {id:"gooo.metric.local-ledger.projection.peak-rss.v1",value:$runtime[0].performance.peak_rss_kib,unit:"KiB",activity:"CompareProjectedClaimReceipts"},
      {id:"gooo.metric.local-ledger.projection.wall-time.v1",value:$runtime[0].performance.wall_ms,unit:"ms",activity:"CompareProjectedClaimReceipts"},
      {id:"gooo.metric.local-ledger.projection.repository-writes.v1",value:$runtime[0].repository_writes,total:0,unit:"writes",activity:"PublishReadinessResolutionReceipt"}
    ]
  }
' > "$output"
