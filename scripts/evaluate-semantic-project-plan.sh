#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 11 ]; then
  echo "usage: evaluate-semantic-project-plan.sh ROOT GRAPH CORE_REPORT ELIGIBILITY PLAN_DIR PRIMARY REPLAY RUNTIME OUTPUT HEAD_SHA PHASE" >&2
  exit 64
fi

root=$1
graph=$2
core_report=$3
eligibility=$4
plan_dir=$5
primary=$6
replay=$7
runtime=$8
output=$9
shift 9
head_sha=$1
phase=$2

denominator="$root/contracts/semantic-project-plan-denominator-v1.json"
lock="$root/contracts/semantic-project-plan-release-lock-v1.json"
contract="$root/contracts/semantic-project-plan-packet-v1.json"
packet="$plan_dir/project-plan.json"
markdown="$plan_dir/project-plan.md"
closed="$plan_dir/evidence/closed.json"
missing="$plan_dir/evidence/missing-producer.json"
unsupported="$plan_dir/evidence/unsupported-kind.json"
ambiguous="$plan_dir/evidence/ambiguous-producer.json"
cycle="$plan_dir/evidence/cycle.json"

for required in "$graph" "$core_report" "$eligibility" "$primary" "$replay" "$runtime" "$denominator" "$lock" "$contract" "$packet" "$markdown" "$closed" "$missing" "$unsupported" "$ambiguous" "$cycle"; do
  if [ ! -f "$required" ]; then
    echo "required evidence unavailable: $required" >&2
    exit 66
  fi
done

jq -S -n \
  --slurpfile denominator "$denominator" \
  --slurpfile lock "$lock" \
  --slurpfile contract "$contract" \
  --slurpfile graph "$graph" \
  --slurpfile core "$core_report" \
  --slurpfile eligibility "$eligibility" \
  --slurpfile primary "$primary" \
  --slurpfile closed "$closed" \
  --slurpfile missing "$missing" \
  --slurpfile unsupported "$unsupported" \
  --slurpfile ambiguous "$ambiguous" \
  --slurpfile cycle "$cycle" \
  --slurpfile packet "$packet" \
  --rawfile markdown "$markdown" \
  --slurpfile replay "$replay" \
  --slurpfile runtime "$runtime" \
  --arg head_sha "$head_sha" \
  --arg phase "$phase" '
  def activity_bound($activity):
    ([$graph[0].nodes[]? | select(.kind=="Activity" and .name==$activity)] | length)==1;
  def indicators_satisfied($r):
    ($r.indicators|length)==8 and all($r.indicators[];
      (if .comparator=="EQ" then .value==.target
       elif .comparator=="GTE" then .value>=.target
       elif .comparator=="LTE" then .value<=.target
       else false end));
  def complete($r):
    $r.schema=="gooo/claim-dependency-causality/v1" and
    $r.candidate_id=="gooo.primitive.claim-dependency-causality.v1" and
    $r.decision=="CLAIM_DEPENDENCY_OBSERVED" and
    $r.resolution.state=="CLOSED" and
    $r.resolution.reason=="CLAIM_DEPENDENCY_CAUSALITY_OBSERVED" and
    $r.summary.activities_total==6 and
    $r.summary.activities_observed==6 and
    $r.summary.recoverable_roots==1 and
    $r.summary.typed_declarations==5 and
    $r.summary.dependency_inputs==8 and
    $r.summary.typed_edges==8 and
    $r.summary.edge_kinds_observed==4 and
    $r.summary.unresolved_inputs==0 and
    $r.summary.cyclic_activities==0 and
    $r.summary.repository_writes==0 and
    $r.kind_counts=={requires:3,supports:2,contradicts:2,failure_entailment:1} and
    ($r.nodes|length)==6 and
    ($r.edges|length)==8 and
    ($r.gaps|length)==0 and
    indicators_satisfied($r) and
    $r.authority.semantic_truth_claimed==false and
    $r.authority.state_propagation_authorized==false and
    $r.authority.core_mutation_authorized==false and
    $r.authority.automatic_merge_allowed==false and
    $r.authority.repository_writes==0;
  def unknown_missing($r):
    $r.schema=="gooo/claim-dependency-causality/v1" and
    $r.decision=="INCOMPLETE" and
    $r.resolution.state=="UNKNOWN" and
    $r.resolution.stage=="DEPENDENCY_DISCOVERY" and
    $r.resolution.step=="BIND_INPUT_PRODUCER" and
    $r.resolution.reason=="CLAIM_INPUT_PRODUCER_UNAVAILABLE" and
    $r.resolution.unknown_class=="DIRECT_MISSING" and
    $r.resolution.next_operation=="DECLARE_INPUT_PRODUCER" and
    ($r.resolution.blocked_by|length)==1 and
    $r.summary.unresolved_inputs==1;
  def refuted($r;$reason):
    $r.schema=="gooo/claim-dependency-causality/v1" and
    $r.decision=="FAIL_CLOSED" and
    $r.resolution.state=="REFUTED" and
    $r.resolution.reason==$reason;
  def dependent($activity):
    ["ExecuteReleasedDependencyPlanner","BindEightProjectDependencies","GenerateJSONProjectPacket","GenerateMarkdownProjectPacket"] | index($activity) != null;
  ($core[0].schema=="gooo/toolchain-cross-platform-release-report/v1" and
    $core[0].head_sha==$lock[0].core.target_commit_sha and
    $core[0].decision=="PASS" and
    $core[0].resolution=="EXACT" and
    $core[0].summary.cases_satisfied==20 and
    $core[0].summary.cases_total==20 and
    $core[0].summary.platform_receipts==3 and
    $core[0].summary.missing_receipts==0 and
    $core[0].summary.case_failures==0 and
    $core[0].summary.head_mismatches==0 and
    $core[0].summary.proof_failures==0 and
    $core[0].summary.unresolved==0 and
    $core[0].summary.repository_writes==0 and
    $core[0].summary.mutation_authorities==0) as $core_ok |
  ($eligibility[0].schema=="gooo/release-eligibility/v1" and
    $eligibility[0].head_sha==$lock[0].core.target_commit_sha and
    $eligibility[0].decision=="EVIDENCE_CLOSED" and
    $eligibility[0].resolution=="EXACT" and
    $eligibility[0].summary.total_work==7 and
    $eligibility[0].summary.closed==7 and
    $eligibility[0].summary.unknown==0 and
    $eligibility[0].summary.refuted==0 and
    $eligibility[0].summary.repository_writes==0) as $eligibility_ok |
  (complete($closed[0])) as $closed_ok |
  (unknown_missing($missing[0])) as $missing_ok |
  (refuted($unsupported[0];"CLAIM_DEPENDENCY_EDGE_KIND_UNSUPPORTED")) as $unsupported_ok |
  (refuted($ambiguous[0];"CLAIM_OUTPUT_PRODUCER_AMBIGUOUS")) as $ambiguous_ok |
  (refuted($cycle[0];"CLAIM_DEPENDENCY_CYCLE_DETECTED")) as $cycle_ok |
  ($contract[0].schema=="gooo/local-ledger/semantic-project-plan-contract/v1" and
    $contract[0].normal.activities==6 and
    $contract[0].normal.dependencies==8 and
    $contract[0].normal.edge_kinds==4 and
    ($contract[0].activity_order|length)==6 and
    ($contract[0].refutations|length)==3 and
    ($contract[0].outputs|length)==2 and
    $contract[0].replay_comparisons==7 and
    ($contract[0].non_claims|length)==7) as $contract_ok |
  ($packet[0].schema=="gooo/local-ledger/semantic-project-plan/v1" and
    $packet[0].decision=="PROJECT_PLAN_PACKET_GENERATED" and
    $packet[0].project.id==$contract[0].project.id and
    $packet[0].primitive==$contract[0].primitive and
    $packet[0].semantics.scope=="STRUCTURAL_DEPENDENCY_ONLY" and
    $packet[0].semantics.conformance_state=="CLOSED" and
    $packet[0].summary=={
      activities:6,recoverable_roots:1,dependencies:8,dependency_kinds:4,
      generated_artifacts:2,unknown_coordinates:6,refuted_boundaries:3
    } and
    $packet[0].kind_counts=={requires:3,supports:2,contradicts:2,failure_entailment:1} and
    ([$packet[0].steps[].activity]==$contract[0].activity_order) and
    ($packet[0].steps|length)==6 and
    ($packet[0].dependencies|length)==8 and
    $packet[0].recovery.stage==$contract[0].unknown.stage and
    $packet[0].recovery.step==$contract[0].unknown.step and
    $packet[0].recovery.reason==$contract[0].unknown.reason and
    $packet[0].recovery.unknown_class==$contract[0].unknown.unknown_class and
    $packet[0].recovery.next_operation==$contract[0].unknown.next_operation and
    ($packet[0].recovery.blocked_by|length)==1 and
    ([$packet[0].refutation_boundaries[].reason]==[$contract[0].refutations[].reason]) and
    $packet[0].non_claims==$contract[0].non_claims and
    $packet[0].authority=={
      repository_mutation_authorized:false,
      automatic_repair_authorized:false,
      automatic_merge_allowed:false,
      semantic_truth_claimed:false,
      state_propagation_authorized:false,
      cross_project_authority:false,
      repository_writes:0
    }) as $packet_ok |
  (($markdown|contains("# Semantic project plan")) and
    ($markdown|contains("## Structural dependencies")) and
    ($markdown|contains("## UNKNOWN recovery")) and
    ($markdown|contains("## REFUTED boundaries")) and
    ($markdown|contains("## Non-claims")) and
    $runtime[0].artifacts.markdown_lines>20) as $markdown_ok |
  ($replay[0].comparisons_satisfied==7 and
    $replay[0].comparisons_total==7 and
    $replay[0].mismatches==0) as $replay_ok |
  ($runtime[0].repository_writes==0 and
    $runtime[0].local_tests==0 and
    $runtime[0].cross_project_required_gates==0 and
    $runtime[0].root_readme_readiness=="EXCLUDED" and
    $runtime[0].authority.repository_mutation_authorized==false and
    $runtime[0].authority.automatic_repair_authorized==false and
    $runtime[0].authority.automatic_merge_allowed==false) as $read_only_ok |
  (if complete($primary[0]) then "CLOSED"
   elif unknown_missing($primary[0]) then "UNKNOWN"
   elif $primary[0].decision=="FAIL_CLOSED" and $primary[0].resolution.state=="REFUTED" then "REFUTED"
   else "INVALID" end) as $primary_mode |
  {
    ObserveCoreClaimDependencyRelease:($runtime[0].releases.core==true and $core_ok),
    BindCoreReleaseEligibility:$eligibility_ok,
    ValidateSemanticProjectProgram:$closed_ok,
    BindProjectPacketContract:$contract_ok,
    ExecuteReleasedDependencyPlanner:$closed_ok,
    BindEightProjectDependencies:($closed_ok and $closed[0].summary.typed_edges==8),
    GenerateJSONProjectPacket:$packet_ok,
    GenerateMarkdownProjectPacket:($packet_ok and $markdown_ok),
    PreserveUnknownRecoveryCoordinates:$missing_ok,
    PreserveRefutedProjectBoundaries:($unsupported_ok and $ambiguous_ok and $cycle_ok),
    ReplaySemanticProjectPacket:$replay_ok,
    PreserveReadOnlyProjectBoundary:$read_only_ok
  } as $facts |
  ([$denominator[0].cells[] |
    . as $cell |
    if (activity_bound($cell.activity)|not) then
      $cell+{state:"REFUTED",reason:"GOOO_META_ACTIVITY_MISSING",unknown_class:null,next_operation:"RESTORE_GOOO_META_ACTIVITY",blocked_by:[]}
    elif dependent($cell.activity) and $primary_mode=="UNKNOWN" then
      $cell+{
        state:"UNKNOWN",
        stage:$primary[0].resolution.stage,
        step:$primary[0].resolution.step,
        reason:$primary[0].resolution.reason,
        unknown_class:$primary[0].resolution.unknown_class,
        next_operation:$primary[0].resolution.next_operation,
        blocked_by:$primary[0].resolution.blocked_by
      }
    elif dependent($cell.activity) and $primary_mode=="REFUTED" then
      $cell+{
        state:"REFUTED",
        stage:$primary[0].resolution.stage,
        step:$primary[0].resolution.step,
        reason:$primary[0].resolution.reason,
        unknown_class:null,
        next_operation:$primary[0].resolution.next_operation,
        blocked_by:($primary[0].resolution.blocked_by//[])
      }
    elif dependent($cell.activity) and $primary_mode=="INVALID" then
      $cell+{state:"REFUTED",reason:"DEPENDENCY_COMMAND_REPORT_INVALID",unknown_class:null,next_operation:"RESTORE_RELEASED_DEPENDENCY_REPORT",blocked_by:[]}
    elif $facts[$cell.activity] then
      $cell+{state:"CLOSED",unknown_class:null,blocked_by:[]}
    else
      $cell+{state:"REFUTED",unknown_class:null,blocked_by:[]}
    end
  ]) as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed_count |
  ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown_count |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted_count |
  ([$cells[]|select(.state!="CLOSED")][0]//null) as $first_nonclosed |
  ([$denominator[0].cells[].activity|select(activity_bound(.))]|length) as $activities_bound |
  {
    schema:"gooo/local-ledger/semantic-project-plan-evaluation/v1",
    subject_sha:$head_sha,
    phase:$phase,
    decision:(if $refuted_count>0 then "FAIL_CLOSED" elif $unknown_count>0 then "SEMANTIC_PROJECT_PLAN_UNKNOWN" else "SEMANTIC_PROJECT_PLAN_PACKET_GENERATED" end),
    claim:{
      state:(if $refuted_count>0 then "REFUTED" elif $unknown_count>0 then "UNKNOWN" else "CLOSED" end),
      stage:($first_nonclosed.stage//"NONE"),
      step:($first_nonclosed.step//"NONE"),
      reason:($first_nonclosed.reason//"TWELVE_OF_TWELVE_PROJECT_PLAN_CELLS_CLOSED"),
      unknown_class:($first_nonclosed.unknown_class//null),
      next_operation:($first_nonclosed.next_operation//"NONE"),
      blocked_by:($first_nonclosed.blocked_by//[])
    },
    summary:{
      cells_total:($cells|length),
      cells_closed:$closed_count,
      cells_unknown:$unknown_count,
      cells_refuted:$refuted_count,
      meta_activities_bound:$activities_bound,
      meta_activities_total:($denominator[0].cells|length),
      project_activities_observed:($closed[0].summary.activities_observed//0),
      project_activities_total:6,
      dependencies_observed:($closed[0].summary.typed_edges//0),
      dependencies_total:8,
      dependency_kinds_observed:($closed[0].summary.edge_kinds_observed//0),
      dependency_kinds_total:4,
      generated_artifacts_observed:(if $packet_ok and $markdown_ok then 2 else 0 end),
      generated_artifacts_total:2,
      unknown_coordinates_observed:(if $missing_ok then 6 else 0 end),
      unknown_coordinates_total:6,
      refuted_boundaries_observed:([$unsupported_ok,$ambiguous_ok,$cycle_ok]|map(select(.==true))|length),
      refuted_boundaries_total:3,
      replay_comparisons_observed:$replay[0].comparisons_satisfied,
      replay_comparisons_total:$replay[0].comparisons_total,
      repository_writes:$runtime[0].repository_writes,
      local_tests:$runtime[0].local_tests,
      cross_project_required_gates:$runtime[0].cross_project_required_gates
    },
    proof_counts:(["FOUNDATION","COHERENCE","REGRESSION"] | map(. as $name | {
      proof_choice:$name,
      observed:([$cells[]|select(.proof_choice==$name and .state=="CLOSED")]|length),
      total:([$cells[]|select(.proof_choice==$name)]|length)
    })),
    indicator_counts:(["DRIVER","OUTCOME","GUARDRAIL"] | map(. as $name | {
      indicator_class:$name,
      observed:([$cells[]|select(.indicator_class==$name and .state=="CLOSED")]|length),
      total:([$cells[]|select(.indicator_class==$name)]|length)
    })),
    metrics:{
      elapsed_ms:$runtime[0].elapsed_ms,
      max_rss_kib:$runtime[0].max_rss_kib,
      repository_files:$runtime[0].inventory.repository_files,
      descendant_directories:$runtime[0].inventory.descendant_directories,
      go_files:$runtime[0].inventory.go.files,
      go_lines:$runtime[0].inventory.go.lines,
      gooo_files:$runtime[0].inventory.gooo.files,
      gooo_lines:$runtime[0].inventory.gooo.lines,
      json_packet_bytes:$runtime[0].artifacts.json_bytes,
      markdown_packet_bytes:$runtime[0].artifacts.markdown_bytes,
      markdown_packet_lines:$runtime[0].artifacts.markdown_lines
    },
    utility:{
      declared_external_use_cases:1,
      evidenced_external_use_cases:0,
      state:"UNKNOWN",
      reason:"EXTERNAL_USER_EVIDENCE_NOT_YET_OBSERVED"
    },
    cells:$cells,
    indicators:[$cells[]|{
      id,activity,indicator_class,proof_choice,state,
      satisfied:(.state=="CLOSED")
    }],
    authority:{
      scope:"READ_ONLY_SEMANTIC_PROJECT_PLAN_PACKET",
      conformance_is_utility:false,
      task_completion_claimed:false,
      proposition_truth_claimed:false,
      state_propagation_authorized:false,
      repository_mutation_authorized:false,
      automatic_repair_authorized:false,
      automatic_merge_allowed:false,
      cross_project_authority:false
    }
  }
' > "$output"
