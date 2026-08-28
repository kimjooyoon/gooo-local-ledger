#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 6; then
  echo "usage: evaluate.sh ROOT CANDIDATE RUNTIME OUTPUT HEAD_SHA PHASE" >&2
  exit 2
fi

root=$1
candidate=$2
runtime=$3
output=$4
head_sha=$5
phase=$6
denominator="$root/contracts/project-readiness-denominator-v1.json"
manifest="$candidate/project.json"

for file in "$denominator" "$manifest" "$runtime"; do
  test -f "$file" || { echo "missing required input: $file" >&2; exit 2; }
done

actual_source_digest=""
if actual_source_digest=$(bash "$root/scripts/source-snapshot.sh" "$candidate" 2>/dev/null); then source_available=true; else source_available=false; fi
file_count=$(find "$candidate" -type f | wc -l | tr -d ' ')
directory_count=$(find "$candidate" -mindepth 1 -type d | wc -l | tr -d ' ')
go_lines=$({ find "$candidate" -type f -name '*.go' -print0 | xargs -0 -r cat || true; } | wc -l | tr -d ' ')
gooo_lines=$({ find "$candidate" -type f -name '*.gooo' -print0 | xargs -0 -r cat || true; } | wc -l | tr -d ' ')
required_observed=0
while IFS= read -r path; do test -s "$candidate/$path" && required_observed=$((required_observed + 1)); done < <(jq -r '.required_paths[]' "$manifest")
required_total=$(jq '.required_paths | length' "$manifest")

entrypoint=$(jq -r '.build_entrypoint' "$manifest")
documentation=$(jq -r '.documentation' "$manifest")
runbook=$(jq -r '.operations_runbook' "$manifest")
release_notes=$(jq -r '.release_notes' "$manifest")

entrypoint_ok=false
if test -s "$candidate/$entrypoint" && grep -Eq '^package main$' "$candidate/$entrypoint" && grep -Eq '^func main\(\)' "$candidate/$entrypoint"; then entrypoint_ok=true; fi
test -s "$candidate/$documentation" && documentation_ok=true || documentation_ok=false
test -s "$candidate/$runbook" && runbook_ok=true || runbook_ok=false
test -s "$candidate/$release_notes" && release_notes_ok=true || release_notes_ok=false

jq -n \
  --slurpfile denominator "$denominator" \
  --slurpfile manifest "$manifest" \
  --slurpfile runtime "$runtime" \
  --arg head_sha "$head_sha" \
  --arg phase "$phase" \
  --arg actual_source_digest "$actual_source_digest" \
  --argjson source_available "$source_available" \
  --argjson file_count "$file_count" \
  --argjson directory_count "$directory_count" \
  --argjson go_lines "$go_lines" \
  --argjson gooo_lines "$gooo_lines" \
  --argjson required_observed "$required_observed" \
  --argjson required_total "$required_total" \
  --argjson entrypoint_ok "$entrypoint_ok" \
  --argjson documentation_ok "$documentation_ok" \
  --argjson runbook_ok "$runbook_ok" \
  --argjson release_notes_ok "$release_notes_ok" '
  def valid_raw_digest: type == "string" and test("^[0-9a-f]{64}$");
  def expected_activities: [$denominator[0].cells[].activity] | sort;
  def actual_activities: [$runtime[0].graph.nodes[]? | select(.kind == "Activity") | .name] | sort;
  def activity_count: (expected_activities - (expected_activities - actual_activities)) | length;
  def cli_receipt_count: ([
    ($runtime[0].version.schema_version == "gooo-version/v1" and $runtime[0].version.version == "0.1.0-dev"),
    ($runtime[0].syntax_check.schema_version == "gooo/diagnostics/v1" and $runtime[0].syntax_check.status == "ok"),
    ($runtime[0].semantic_check.schema_version == "gooo/diagnostics/v1" and $runtime[0].semantic_check.status == "ok" and ($runtime[0].semantic_check.semantic_hash | valid_raw_digest)),
    ($runtime[0].graph.schema_version == "gooo-graph/v1" and ($runtime[0].graph.source_digest | valid_raw_digest) and actual_activities == expected_activities)
  ] | map(select(. == true)) | length);
  def authority_ok: $manifest[0].schema == "gooo/local-ledger/project/v1" and ($manifest[0].source_paths|length)==2 and ($manifest[0].required_paths|length)==5;
  def source_state: if $source_available != true then "UNKNOWN" elif $actual_source_digest == $runtime[0].expected_source_digest then "CLOSED" else "REFUTED" end;
  def closed($cell): $cell + {state:"CLOSED",resolution:"EXACT",reason:$cell.closed_reason,next_operation:"NONE"};
  def unknown($cell): $cell + {state:"UNKNOWN",resolution:"PREREQUISITE_CLASS",reason:$cell.unknown_reason,next_operation:$cell.next_operation};
  def refuted($cell;$reason;$next): $cell + {state:"REFUTED",resolution:"EXACT",reason:$reason,next_operation:$next};
  def base_decide($cell):
    if $cell.id=="PROJECT_AUTHORITY" then if authority_ok then closed($cell) else refuted($cell;"PROJECT_MANIFEST_INVALID";"RESTORE_PROJECT_MANIFEST") end
    elif $cell.id=="SOURCE_SNAPSHOT" then if source_state=="CLOSED" then closed($cell) elif source_state=="UNKNOWN" then unknown($cell) else refuted($cell;"SOURCE_SNAPSHOT_MISMATCH";"RESTORE_EXPECTED_SOURCE_SNAPSHOT") end
    elif $cell.id=="FILE_INVENTORY" then if $file_count>0 and $directory_count>0 then closed($cell) else unknown($cell) end
    elif $cell.id=="LANGUAGE_LINES" then if $go_lines>0 and $gooo_lines>0 then closed($cell) else unknown($cell) end
    elif $cell.id=="BUILD_ENTRYPOINT" then if $entrypoint_ok then closed($cell) else unknown($cell) end
    elif $cell.id=="DOCUMENTATION" then if $documentation_ok then closed($cell) else unknown($cell) end
    elif $cell.id=="OPERATIONS_RUNBOOK" then if $runbook_ok then closed($cell) else unknown($cell) end
    elif $cell.id=="RELEASE_NOTES" then if $release_notes_ok then closed($cell) else unknown($cell) end
    elif $cell.id=="RELEASED_GOOO_BINDING" then if cli_receipt_count==4 and activity_count==12 then closed($cell) else refuted($cell;"RELEASED_GOOO_BINDING_MISMATCH";"RESTORE_RELEASED_GOOO_BINDING") end
    elif $cell.id=="RESOURCE_SAMPLE" then if $runtime[0].performance.graph_peak_rss_kib>0 and $runtime[0].performance.graph_wall_ms>=0 then closed($cell) else unknown($cell) end
    elif $cell.id=="READ_ONLY_EFFECT" then if $runtime[0].repository.writes==0 and $runtime[0].repository.before_digest==$runtime[0].repository.after_digest then closed($cell) elif $runtime[0].repository.writes==null then unknown($cell) else refuted($cell;"REPOSITORY_WRITE_EFFECT_OBSERVED";"REMOVE_INPUT_REPOSITORY_WRITES") end
    else $cell end;
  ($denominator[0].cells[0:11] | map(base_decide(.) | del(.closed_reason,.unknown_reason))) as $base |
  ([$base[]|select(.state=="REFUTED")][0] // null) as $base_refuted |
  ([$base[]|select(.state=="UNKNOWN")][0] // null) as $base_unknown |
  ($denominator[0].cells[11]) as $user_cell |
  (if $base_refuted != null then refuted($user_cell;"RELEASE_DECISION_REFUTED";"RESOLVE_FIRST_REFUTATION")
   elif $base_unknown != null then unknown($user_cell)
   else closed($user_cell) end | del(.closed_reason,.unknown_reason)) as $user_decision_cell |
  ($base + [$user_decision_cell]) as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed_count |
  ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown_count |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted_count |
  ([$cells[]|select(.state=="REFUTED")][0] // null) as $first_refuted |
  ([$cells[]|select(.state=="UNKNOWN")][0] // null) as $first_unknown |
  {
    schema:"gooo/local-ledger/readiness-report/v1",phase:$phase,subject_sha:$head_sha,project:$manifest[0].id,
    decision:(if $refuted_count>0 then "FAIL_CLOSED" elif $unknown_count>0 then "NOT_READY" else "RELEASE_READY" end),
    claim:{id:"local://claim/release-readiness",state:(if $refuted_count>0 then "REFUTED" elif $unknown_count>0 then "UNKNOWN" else "CLOSED" end),
      stage:(if $refuted_count>0 then $first_refuted.stage elif $unknown_count>0 then $first_unknown.stage else null end),
      step:(if $refuted_count>0 then $first_refuted.step elif $unknown_count>0 then $first_unknown.step else null end),
      reason:(if $refuted_count>0 then $first_refuted.reason elif $unknown_count>0 then $first_unknown.reason else "RELEASE_READINESS_CLOSED" end),
      next_operation:(if $refuted_count>0 then $first_refuted.next_operation elif $unknown_count>0 then $first_unknown.next_operation else "NONE" end)},
    summary:{total:12,closed:$closed_count,unknown:$unknown_count,refuted:$refuted_count,repository_writes:$runtime[0].repository.writes},
    inventory:{files:$file_count,descendant_directories:$directory_count,go_physical_lines:$go_lines,gooo_physical_lines:$gooo_lines,required_artifacts_observed:$required_observed,required_artifacts_total:$required_total},
    performance:$runtime[0].performance,
    authority:{binding:"RELEASED_GOOO_GRAPH_ACTIVITY_SET",activity_bindings:activity_count,activity_total:12,source_spans:"NOT_AVAILABLE"},
    cells:$cells,
    proofs:(["FOUNDATION","COHERENCE","REGRESSION"]|map(. as $proof|{choice:$proof,closed:([$cells[]|select(.proof_choice==$proof and .state=="CLOSED")]|length),total:([$cells[]|select(.proof_choice==$proof)]|length)})),
    indicators:[
      {id:"gooo.metric.local-ledger.readiness.v1",value:$closed_count,total:12,unit:"cells",state:(if $closed_count==12 then "SATISFIED" else "GAP" end),activity:"CloseReleaseDecision"},
      {id:"gooo.metric.local-ledger.files.v1",value:$file_count,unit:"files",state:"OBSERVED",activity:"CountProjectInventory"},
      {id:"gooo.metric.local-ledger.directories.v1",value:$directory_count,unit:"directories",state:"OBSERVED",activity:"CountProjectInventory"},
      {id:"gooo.metric.local-ledger.go-lines.v1",value:$go_lines,unit:"physical_lines",state:"OBSERVED",activity:"CountLanguageLines"},
      {id:"gooo.metric.local-ledger.gooo-lines.v1",value:$gooo_lines,unit:"physical_lines",state:"OBSERVED",activity:"CountLanguageLines"},
      {id:"gooo.metric.local-ledger.required-artifacts.v1",value:$required_observed,total:$required_total,unit:"artifacts",state:(if $required_observed==$required_total then "SATISFIED" else "GAP" end),activity:"CloseReleaseDecision"},
      {id:"gooo.metric.local-ledger.cli-receipts.v1",value:cli_receipt_count,total:4,unit:"receipts",state:(if cli_receipt_count==4 then "SATISFIED" else "GAP" end),activity:"BindReleasedGoooSemantics"},
      {id:"gooo.metric.local-ledger.activity-bindings.v1",value:activity_count,total:12,unit:"activities",state:(if activity_count==12 then "SATISFIED" else "GAP" end),activity:"BindReleasedGoooSemantics"},
      {id:"gooo.metric.local-ledger.graph-peak-rss.v1",value:$runtime[0].performance.graph_peak_rss_kib,unit:"KiB",state:"OBSERVED",activity:"ObserveResourceUsage"},
      {id:"gooo.metric.local-ledger.graph-wall-time.v1",value:$runtime[0].performance.graph_wall_ms,unit:"ms",state:"OBSERVED",activity:"ObserveResourceUsage"},
      {id:"gooo.metric.local-ledger.repository-writes.v1",value:$runtime[0].repository.writes,total:1,unit:"writes",state:(if $runtime[0].repository.writes==0 then "SATISFIED" else "REFUTED" end),activity:"ObserveReadOnlyEffect"}
    ]
  }' > "$output"
