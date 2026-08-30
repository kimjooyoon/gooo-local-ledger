#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 7 ]; then
  echo "usage: evaluate-released-domain-envelope-v2-adoption.sh ROOT CORE_RECEIPTS FACTS RUNTIME INVENTORY OUTPUT SUBJECT_SHA" >&2
  exit 64
fi

root=$1
core_receipts=$2
facts=$3
runtime=$4
inventory=$5
output=$6
subject_sha=$7

denominator="$root/contracts/released-domain-envelope-v2-adoption-denominator-v1.json"
lock="$root/contracts/released-domain-envelope-v2-adoption-release-lock-v1.json"
for required in "$denominator" "$lock" "$core_receipts" "$facts" "$runtime" "$inventory"; do
  if [ ! -f "$required" ]; then
    echo "required adoption evidence unavailable: $required" >&2
    exit 66
  fi
done

jq -S -n \
  --slurpfile denominator "$denominator" --slurpfile lock "$lock" \
  --slurpfile core "$core_receipts" --slurpfile facts "$facts" \
  --slurpfile runtime "$runtime" --slurpfile inventory "$inventory" \
  --arg subject_sha "$subject_sha" '
  $denominator[0] as $d |
  $lock[0] as $l |
  $facts[0] as $f |
  $runtime[0] as $rt |
  $inventory[0] as $inv |
  ($core[0]|map({key:.selector.name,value:.})|from_entries) as $receipt_by |
  def strip_cell: del(.depends_on);
  def digest($value): (($value|type)=="string" and ($value|test("^[0-9a-f]{64}$")));
  def expected($name): $d.expectations[$name];
  def required_cell_ids: ["AUTHORITY_BOUNDARY","CORE_RELEASE","DETERMINISTIC_REPLAY","EIGHT_FILE_ENVELOPE","INTERCHANGE_SPEC_RELEASE","LOCAL_DEPENDENCY_SOURCE","LOCAL_RELEASE","META_ACTIVITY_AUTHORITY","PRODUCT_PROJECTION","READ_ONLY_CONFORMANCE","REFUTED_COUNTEREXAMPLES","UNKNOWN_CAUSALITY"];
  def required_activities: ["ObserveCurrentCoreRelease","ObserveInterchangeSpecRelease","ObserveLocalProductRelease","ObserveMetaActivityAuthority","ObserveLocalDependencySource","ProjectProductEnvelope","PublishEightFileEnvelope","VerifyReadOnlyConformance","PreserveUnknownCausality","VerifyDeterministicReplay","RefuteCounterexamples","PreserveAuthorityBoundary"];
  def required_pairs: ["AUTHORITY_BOUNDARY=PreserveAuthorityBoundary","CORE_RELEASE=ObserveCurrentCoreRelease","DETERMINISTIC_REPLAY=VerifyDeterministicReplay","EIGHT_FILE_ENVELOPE=PublishEightFileEnvelope","INTERCHANGE_SPEC_RELEASE=ObserveInterchangeSpecRelease","LOCAL_DEPENDENCY_SOURCE=ObserveLocalDependencySource","LOCAL_RELEASE=ObserveLocalProductRelease","META_ACTIVITY_AUTHORITY=ObserveMetaActivityAuthority","PRODUCT_PROJECTION=ProjectProductEnvelope","READ_ONLY_CONFORMANCE=VerifyReadOnlyConformance","REFUTED_COUNTEREXAMPLES=RefuteCounterexamples","UNKNOWN_CAUSALITY=PreserveUnknownCausality"];
  def core_resolution($cell):
    ($receipt_by[$cell.activity]//null) as $r |
    if $r==null then
      {state:"UNKNOWN",occurrences:0,stage:"CORE_META_ACTIVITY",step:"RESOLVE_ACTIVITY_CARDINALITY",reason:"ACTIVITY_NOT_FOUND",unknown_class:"DIRECT_MISSING",next_operation:"PROVIDE_CORE_ACTIVITY_RESOLUTION_RECEIPT",blocked_by:[]}
    elif $r.schema=="gooo/activity-cardinality-resolution/v1" and $r.selector.name==$cell.activity and $r.decision=="CLOSED" and $r.occurrences==1 and $r.claim.state=="CLOSED" and $r.claim.reason=="ACTIVITY_UNIQUELY_RESOLVED" then
      {state:"CLOSED",occurrences:1,stage:null,step:null,reason:"CORE_ACTIVITY_RESOLUTION_CLOSED",unknown_class:null,next_operation:"NONE",blocked_by:[]}
    elif $r.schema=="gooo/activity-cardinality-resolution/v1" and $r.selector.name==$cell.activity and $r.decision=="UNKNOWN" and $r.occurrences==0 and $r.claim.state=="UNKNOWN" and $r.claim.reason=="ACTIVITY_NOT_FOUND" and (($r.claim.stage|type)=="string") and (($r.claim.step|type)=="string") and (($r.claim.unknown_class|IN("DIRECT_MISSING","DEPENDENCY_BLOCKED"))) and (($r.claim.next_operation|type)=="string") and (($r.claim.blocked_by|type)=="array") and (($r.claim.unknown_class=="DIRECT_MISSING" and ($r.claim.blocked_by|length)==0) or ($r.claim.unknown_class=="DEPENDENCY_BLOCKED" and ($r.claim.blocked_by|length)>0)) then
      {state:"UNKNOWN",occurrences:0,stage:$r.claim.stage,step:$r.claim.step,reason:$r.claim.reason,unknown_class:$r.claim.unknown_class,next_operation:$r.claim.next_operation,blocked_by:$r.claim.blocked_by}
    else
      {state:"REFUTED",occurrences:($r.occurrences//0),stage:"CORE_META_ACTIVITY",step:"RESOLVE_ACTIVITY_CARDINALITY",reason:"UNRECOGNIZED_CORE_ACTIVITY_RESOLUTION_DECISION",unknown_class:null,next_operation:"RESTORE_CORE_ACTIVITY_RESOLUTION_RECEIPT",blocked_by:[]}
    end;
  def fact($id):
    if $id=="CORE_RELEASE" then $f.immutable.core_identity_verified
    elif $id=="INTERCHANGE_SPEC_RELEASE" then $f.immutable.kit_identity_verified
    elif $id=="LOCAL_RELEASE" then $f.immutable.product_identity_verified
    elif $id=="META_ACTIVITY_AUTHORITY" then ($f.meta.activities_observed==$f.meta.activities_total and $f.meta.graph_activities==$f.meta.activities_total and $f.meta.receipts_total==$f.meta.activities_total)
    elif $id=="LOCAL_DEPENDENCY_SOURCE" then ($f.source_artifacts.project_relation_count==expected("typed_relations") and $f.source_artifacts.project_evidence_count==expected("typed_relations") and $f.source_artifacts.project_resolution_count==expected("typed_relations") and $f.source_artifacts.project_unknown_count==0 and $f.source_artifacts.relation_lines==$f.source_artifacts.project_relation_count and $f.source_artifacts.evidence_lines==$f.source_artifacts.project_evidence_count and $f.source_artifacts.resolution_lines==$f.source_artifacts.project_resolution_count)
    elif $id=="PRODUCT_PROJECTION" then ($f.bundle.product_owned_projection==1 and $f.bundle.product_owned_projection_total==1 and $f.projection_inputs.local_projector_identity==true and $f.projection_inputs.projection_owner_observed==true and $f.projection_inputs.projection_owner=="LOCAL_LEDGER" and $f.projection_inputs.core_activities==$f.meta.activities_total and $f.projection_inputs.graph_activities==$f.meta.activities_total and $f.projection_inputs.relation_count==$f.source_artifacts.project_relation_count and $f.projection_inputs.evidence_count==$f.source_artifacts.project_evidence_count and $f.projection_inputs.resolution_count==$f.source_artifacts.project_resolution_count and $f.projection_inputs.conformer_decision=="CONFORMANT" and $f.projection_inputs.conformer_relations==expected("typed_relations") and $f.projection_inputs.conformer_evidence==expected("typed_relations") and $f.projection_inputs.conformer_resolutions==expected("typed_relations"))
    elif $id=="EIGHT_FILE_ENVELOPE" then ($f.bundle.envelope_files==expected("envelope_files") and $f.bundle.envelope_files_total==$f.conformer.files and $f.conformer.files==expected("envelope_files") and $f.conformer.checks==expected("conformer_checks") and $f.conformer.checks_total==$f.conformer.total)
    elif $id=="READ_ONLY_CONFORMANCE" then ($f.conformer.decision=="CONFORMANT" and $f.conformer.checks==expected("conformer_checks") and $f.conformer.checks_total==$f.conformer.total and $f.conformer.gates==0 and $f.contract.product_generation_authorized==false)
    elif $id=="UNKNOWN_CAUSALITY" then ($f.unknown_coordinates.report_decision=="RELEASED_DOMAIN_ENVELOPE_V2_UNKNOWN" and $f.unknown_coordinates.cells==expected("unknown_cases") and $f.unknown_coordinates.direct_missing==expected("unknown_direct_cases") and $f.unknown_coordinates.dependency_blocked==expected("unknown_dependency_cases") and $f.unknown_coordinates.six_fields==expected("unknown_fields") and $f.unknown_coordinates.all_six_fields==true and digest($f.unknown_coordinates.report_sha256))
    elif $id=="DETERMINISTIC_REPLAY" then ($f.bundle.deterministic_replay==expected("source_replay_comparisons") and $f.bundle.deterministic_replay_total==expected("source_replay_comparisons") and $f.source_artifacts.replay_file_comparisons_satisfied==$f.source_artifacts.replay_file_comparisons_total and $f.source_artifacts.replay_file_comparisons_total==expected("file_replay_comparisons") and digest($f.source_artifacts.payload_sha256) and digest($f.source_artifacts.checksums_sha256))
    elif $id=="REFUTED_COUNTEREXAMPLES" then ($f.adversarial.reports_observed==expected("refuted_counterexample_reports") and $f.adversarial.malformed.decision=="FAIL_CLOSED" and $f.adversarial.fixed_point.decision=="FAIL_CLOSED" and $f.adversarial.malformed.refuted_cells>0 and $f.adversarial.fixed_point.refuted_cells==$d.total and $f.adversarial.malformed.reason=="UNRECOGNIZED_CORE_ACTIVITY_RESOLUTION_DECISION" and $f.adversarial.fixed_point.reason=="UNRECOGNIZED_CORE_ACTIVITY_RESOLUTION_DECISION" and digest($f.adversarial.malformed.report_sha256) and digest($f.adversarial.fixed_point.report_sha256))
    elif $id=="AUTHORITY_BOUNDARY" then ($rt.repository_writes==0 and $rt.local_test_executions==0 and $rt.cross_project_required_gates==0 and $rt.authority.repository_mutation_authorized==false and $rt.authority.product_generation_authorized==false and $rt.authority.product_generation_scope=="CALLER_OWNED_TEMP_OUTPUT_ONLY" and $f.immutable.specification_repository_checkout==0 and $f.immutable.conformer_copy==0)
    else false end;
  ($d.total==12 and ($d.cells|length)==12 and
   ([ $d.cells[].id ]|sort)==required_cell_ids and
   ([ $d.cells[].activity ]|sort)==(required_activities|sort) and
   ([ $d.cells[]|"\(.id)=\(.activity)" ]|sort)==required_pairs and
   ([ $d.cells[].activity ]|unique|length)==12 and
   ([ $d.cells[]|select(.proof_choice=="FOUNDATION")]|length)==4 and
   ([ $d.cells[]|select(.proof_choice=="COHERENCE")]|length)==4 and
   ([ $d.cells[]|select(.proof_choice=="REGRESSION")]|length)==4 and
   ([ $d.cells[]|select(.indicator_class=="DRIVER")]|length)==4 and
   ([ $d.cells[]|select(.indicator_class=="OUTCOME")]|length)==4 and
   ([ $d.cells[]|select(.indicator_class=="GUARDRAIL")]|length)==4) as $denominator_ok |
  (([ $core[0][]|select(.decision=="FIXED_POINT" or (.decision//"")=="FIXED_POINT") ]|length)>0) as $fixed_point_seen |
  (reduce $d.cells[] as $cell ([ ];
    . as $prior |
    (core_resolution($cell)) as $core_state |
    ([$prior[] as $p|select((($cell.depends_on//[])|index($p.id))!=null and $p.state=="REFUTED")|$p]) as $refuted_predecessors |
    ([$prior[] as $p|select((($cell.depends_on//[])|index($p.id))!=null and $p.state=="UNKNOWN")|$p]) as $unknown_predecessors |
    (if ($fixed_point_seen or ($denominator_ok|not)) then
       ($cell|strip_cell)+{state:"REFUTED",occurrences:0,stage:"CORE_META_ACTIVITY",step:"RESOLVE_ACTIVITY_CARDINALITY",reason:(if $fixed_point_seen then "UNRECOGNIZED_CORE_ACTIVITY_RESOLUTION_DECISION" else "ADOPTION_DENOMINATOR_INVALID" end),unknown_class:null,next_operation:"RESTORE_CORE_META_ACTIVITY",blocked_by:[]}
     elif $core_state.state=="REFUTED" then
       ($cell|strip_cell)+{state:"REFUTED",occurrences:$core_state.occurrences,stage:$core_state.stage,step:$core_state.step,reason:$core_state.reason,unknown_class:null,next_operation:$core_state.next_operation,blocked_by:[]}
     elif $core_state.state=="UNKNOWN" then
       ($cell|strip_cell)+{state:"UNKNOWN",occurrences:$core_state.occurrences,stage:$core_state.stage,step:$core_state.step,reason:$core_state.reason,unknown_class:$core_state.unknown_class,next_operation:$core_state.next_operation,blocked_by:$core_state.blocked_by}
     elif ($refuted_predecessors|length)>0 then
       ($cell|strip_cell)+{state:"REFUTED",occurrences:0,stage:"DEPENDENCY_RESOLUTION",step:"BLOCKED_BY_REFUTED_PREDECESSOR",reason:"DEPENDENCY_REFUTED",unknown_class:null,next_operation:"RESTORE_REFUTED_PREDECESSOR",blocked_by:[$refuted_predecessors[].id]}
     elif ($unknown_predecessors|length)>0 then
       ($cell|strip_cell)+{state:"UNKNOWN",occurrences:0,stage:"DEPENDENCY_RESOLUTION",step:"WAIT_FOR_PREDECESSOR",reason:"DEPENDENCY_BLOCKED",unknown_class:"DEPENDENCY_BLOCKED",next_operation:"RESOLVE_BLOCKED_PREDECESSOR",blocked_by:[$unknown_predecessors[].id]}
     elif fact($cell.id) then
       ($cell|strip_cell)+{state:"CLOSED",occurrences:1,stage:null,step:null,reason:"FACT_OBSERVED",unknown_class:null,next_operation:"NONE",blocked_by:[]}
     else
       ($cell|strip_cell)+{state:"REFUTED",occurrences:0,stage:"PRODUCT_EVIDENCE",step:$cell.step,reason:$cell.reason,unknown_class:null,next_operation:$cell.next_operation,blocked_by:[]}
     end) as $next |
    $prior + [$next]
  )) as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed |
  ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted |
  ([$cells[]|select(.state!="CLOSED")][0]//null) as $first |
  {
    schema:"gooo/local-ledger/released-domain-envelope-v2-adoption-evaluation/v1",
    subject_sha:$subject_sha,
    decision:(if $refuted>0 then "FAIL_CLOSED" elif $unknown>0 then "RELEASED_DOMAIN_ENVELOPE_V2_UNKNOWN" else "RELEASED_DOMAIN_ENVELOPE_V2_CANDIDATE_CLOSED" end),
    claim:(if $first==null then
      {state:"CLOSED",occurrences:1,stage:null,step:null,reason:"TWELVE_OF_TWELVE_ENVELOPE_CELLS_CLOSED",unknown_class:null,next_operation:"NONE",blocked_by:[]}
    else
      {state:$first.state,occurrences:$first.occurrences,stage:$first.stage,step:$first.step,reason:$first.reason,unknown_class:$first.unknown_class,next_operation:$first.next_operation,blocked_by:$first.blocked_by}
    end),
    summary:{
      cells_total:$d.total,cells_closed:$closed,cells_unknown:$unknown,cells_refuted:$refuted,
      normal_cases:(if $closed==$d.total then 1 else 0 end),unknown_cases:(if $unknown>0 then 1 else 0 end),refuted_cases:(if $refuted>0 then 1 else 0 end),
      meta_activities_observed:$f.meta.activities_observed,meta_activities_total:$f.meta.activities_total,
      generated_artifacts_observed:$f.bundle.envelope_files,generated_artifacts_total:expected("envelope_files"),
      source_project_plan_artifacts_observed:$f.source_artifacts.source_project_plan_artifacts,source_project_plan_artifacts_total:expected("source_project_plan_artifacts"),
      user_paths_observed:(($f.user_paths.normal//0)+($f.user_paths.unknown//0)+($f.user_paths.refuted//0)),user_paths_total:(($f.user_paths.normal//0)+($f.user_paths.unknown//0)+($f.user_paths.refuted//0)),
      product_owned_projection:$f.bundle.product_owned_projection,product_owned_projection_total:$f.bundle.product_owned_projection_total,
      envelope_files:$f.bundle.envelope_files,envelope_files_total:$f.bundle.envelope_files_total,
      relations:$f.bundle.relations,relations_total:$f.bundle.relations_total,
      evidence:$f.bundle.evidence,evidence_total:$f.bundle.evidence_total,
      resolutions:$f.bundle.resolutions,resolutions_total:$f.bundle.resolutions_total,
      conformer_checks:$f.conformer.checks,conformer_checks_total:$f.conformer.checks_total,
      deterministic_replay:$f.bundle.deterministic_replay,deterministic_replay_total:$f.bundle.deterministic_replay_total,
      file_replay_comparisons_observed:$f.source_artifacts.replay_file_comparisons_satisfied,file_replay_comparisons_total:$f.source_artifacts.replay_file_comparisons_total,
      refuted_counterexample_reports:$f.adversarial.reports_observed,
      unknown_coordinates_observed:$f.unknown_coordinates.six_fields,unknown_coordinates_total:expected("unknown_fields"),
      repository_writes:$rt.repository_writes,local_test_executions:$rt.local_test_executions,cross_project_required_gates:$rt.cross_project_required_gates
    },
    cases:{normal:($f.user_paths.normal//null),unknown:($f.user_paths.unknown//null),refuted:($f.user_paths.refuted//null)},
    unknown_classes:{direct_missing:$f.unknown_coordinates.direct_missing,dependency_blocked:$f.unknown_coordinates.dependency_blocked,total:($f.unknown_coordinates.direct_missing+$f.unknown_coordinates.dependency_blocked),fields:["stage","step","reason","unknown_class","next_operation","blocked_by"]},
    adversarial:$f.adversarial,
    proof_counts:(["FOUNDATION","COHERENCE","REGRESSION"]|map(. as $p|{proof_choice:$p,observed:([$cells[]|select(.proof_choice==$p and .state=="CLOSED")]|length),total:([$cells[]|select(.proof_choice==$p)]|length)})),
    indicator_counts:(["DRIVER","OUTCOME","GUARDRAIL"]|map(. as $i|{indicator_class:$i,observed:([$cells[]|select(.indicator_class==$i and .state=="CLOSED")]|length),total:([$cells[]|select(.indicator_class==$i)]|length)})),
    adoption:{released_domain_adoption:{observed:0,total:1,state:"UNKNOWN"},external_utility:{observed:0,total:1,state:"UNKNOWN",reason:"EXTERNAL_USER_EVIDENCE_NOT_YET_OBSERVED"}},
    external_utility_declarations:1,external_utility_evidence:0,
    improvement:{before:null,after:null,state:"UNKNOWN",reason:"EXACT_BEFORE_AFTER_PAIR_NOT_PROVIDED"},
    metrics:{
      peak_rss_kib:$rt.peak_rss_kib,wall_ms:$rt.wall_ms,
      repository_files:$inv.repository_files,regular_files:$inv.regular_files,descendant_directories:$inv.descendant_directories,
      go_files:$inv.go.files,go_lines:$inv.go.lines,gooo_files:$inv.gooo.files,gooo_lines:$inv.gooo.lines
    },
    authority:{
      projection_owner:$f.projection_inputs.projection_owner,envelope_format_owner:"INTERCHANGE_SPECIFICATION",
      product_generation_authorized:$rt.authority.product_generation_authorized,generation_output_scope:$rt.authority.product_generation_scope,
      repository_writes:$rt.repository_writes,local_test_executions:$rt.local_test_executions,cross_project_required_gates:$rt.cross_project_required_gates,
      semantic_truth_claimed:false,automatic_merge_allowed:$rt.authority.automatic_merge_allowed,release_adoption_claimed:false
    },
    cells:$cells
  }
' > "$output"
