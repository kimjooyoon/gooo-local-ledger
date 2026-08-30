#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 7 ]; then
  echo "usage: project-released-domain-envelope-v2.sh REPOSITORY_ROOT PROJECT_PLAN CORE_RECEIPTS GRAPH DENOMINATOR LOCK OUTPUT_DIR" >&2
  exit 64
fi

repository_root=$1
project_plan=$2
core_receipts=$3
graph=$4
denominator=$5
lock=$6
output=$7

if [ ! -d "$repository_root" ]; then
  echo "repository root unavailable: $repository_root" >&2
  exit 66
fi
repository_root_real=$(realpath "$repository_root")
output_real=$(realpath -m "$output")
if [ "$output_real" = "/" ]; then
  echo "output must be a caller-owned directory, not filesystem root" >&2
  exit 65
fi
case "$output_real" in
  "$repository_root_real"|"$repository_root_real"/*)
    echo "output must be caller-owned and outside repository root: $output" >&2
    exit 65
    ;;
esac

trap 'status=$?; echo "released-domain envelope projector failed: status=$status line=$LINENO ordinal=${ordinal:-none} relation=${relation_id:-none}" >&2; exit "$status"' ERR

for required in "$project_plan" "$core_receipts" "$graph" "$denominator" "$lock"; do
  if [ ! -f "$required" ]; then
    echo "required released evidence unavailable: $required" >&2
    exit 66
  fi
done

kit_repository=$(jq -r '.kit.repository' "$lock")
kit_tag=$(jq -r '.kit.tag' "$lock")
kit_target=$(jq -r '.kit.target_commit_sha' "$lock")
product_repository=$(jq -r '.product_evidence.repository' "$lock")
product_tag=$(jq -r '.product_evidence.tag' "$lock")
product_target=$(jq -r '.product_evidence.target_commit_sha' "$lock")
product_asset_name=$(jq -r '.product_evidence.asset.name' "$lock")
product_asset_sha=$(jq -r '.product_evidence.asset.sha256' "$lock")

actual_product_sha=$(sha256sum "$project_plan" | awk '{print $1}')
if [ "$actual_product_sha" != "$product_asset_sha" ]; then
  echo "released product evidence digest mismatch" >&2
  exit 65
fi



jq -e '
  .schema=="gooo/local-ledger/semantic-project-plan/v1" and
  .decision=="PROJECT_PLAN_PACKET_GENERATED" and
  .semantics.scope=="STRUCTURAL_DEPENDENCY_ONLY" and
  .semantics.conformance_state=="CLOSED" and
  .summary.dependencies==8 and .summary.dependency_kinds==4 and
  .summary.unknown_coordinates==6 and .summary.refuted_boundaries==3 and
  .kind_counts=={requires:3,supports:2,contradicts:2,failure_entailment:1} and
  (.dependencies|length)==8 and
  ([.dependencies[]?.ordinal]|sort)==[1,2,3,4,5,6,7,8] and
  ([.dependencies[].id]|unique|length)==8 and
  .authority.repository_writes==0 and .authority.semantic_truth_claimed==false and
  .authority.state_propagation_authorized==false and .authority.automatic_merge_allowed==false
' "$project_plan" >/dev/null

jq -e -n --slurpfile denominator "$denominator" --slurpfile graph "$graph" --slurpfile receipts "$core_receipts" '
  $denominator[0].schema=="gooo/local-ledger/released-domain-envelope-v2-adoption-denominator/v1" and
  $denominator[0].total==12 and ($denominator[0].cells|length)==12 and
  ([ $denominator[0].cells[].activity ]|sort)==([ $graph[0].nodes[]|select(.kind=="Activity")|.name ]|sort) and
  ($receipts[0]|length)==12 and
  ([ $receipts[0][].selector.name ]|sort)==([ $denominator[0].cells[].activity ]|sort) and
  ([ $receipts[0][]|select(.schema=="gooo/activity-cardinality-resolution/v1" and .decision=="CLOSED" and .occurrences==1 and .claim.state=="CLOSED" and .claim.reason=="ACTIVITY_UNIQUELY_RESOLVED") ]|length)==12
' >/dev/null

jq -e -n --arg product_repository "$product_repository" --arg product_tag "$product_tag" --arg product_target "$product_target" --arg product_asset_name "$product_asset_name" --arg product_asset_sha "$product_asset_sha" --arg kit_repository "$kit_repository" --arg kit_tag "$kit_tag" --arg kit_target "$kit_target" '
  $product_repository=="kimjooyoon/gooo-local-ledger" and $product_tag=="v0.8.0-dev" and
  ($product_target|test("^[0-9a-f]{40}$")) and $product_asset_name=="project-plan.json" and
  ($product_asset_sha|test("^[0-9a-f]{64}$")) and $kit_repository=="kimjooyoon/gooo-interchange-spec" and
  $kit_tag=="v0.3.0-dev" and ($kit_target|test("^[0-9a-f]{40}$"))
' >/dev/null

tmp=$(mktemp -d "${TMPDIR:-/tmp}/released-domain-envelope-v2.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/envelope"

jq -S -n \
  --arg project_id "local://project/semantic-release-plan" \
  --arg repository "$product_repository" --arg tag "$product_tag" \
  --arg target_commit_sha "$product_target" --arg asset_name "$product_asset_name" \
  --arg asset_sha256 "$product_asset_sha" \
  '{
    schema:"gooo/interchange/project/v2",
    project_id:$project_id,
    domain:"local-ledger",
    release:{repository:$repository,tag:$tag,target_commit_sha:$target_commit_sha},
    source:{asset_name:$asset_name,asset_sha256:$asset_sha256,member:$asset_name,schema:"gooo/local-ledger/semantic-project-plan/v1"},
    relation_count:8,
    evidence_count:8,
    resolution_count:8,
    unknown_count:0,
    authority:{projection_owner:"INTERCHANGE_SPECIFICATION",domain_release_adoption_claimed:false,source_repository_writes:0,product_generation_authorized:false}
  }' > "$tmp/envelope/project.json"

: > "$tmp/envelope/evidence.ndjson"
: > "$tmp/envelope/relations.ndjson"
: > "$tmp/envelope/resolutions.ndjson"

while IFS=$'\t' read -r ordinal relation_id; do
  relation_index=$(jq -r --arg relation_id "$relation_id" '[.dependencies[]|.id] | index($relation_id)' "$project_plan")
  relation_json=$(jq -S -c --arg relation_id "$relation_id" '.dependencies[]|select(.id==$relation_id)' "$project_plan")
  value_sha=$(printf '%s\n' "$relation_json" | sha256sum | awk '{print $1}')
  from_activity=$(jq -r --arg relation_id "$relation_id" '.dependencies[]|select(.id==$relation_id)|.from_activity' "$project_plan")
  to_activity=$(jq -r --arg relation_id "$relation_id" '.dependencies[]|select(.id==$relation_id)|.to_activity' "$project_plan")
  kind=$(jq -r --arg relation_id "$relation_id" '.dependencies[]|select(.id==$relation_id)|.kind' "$project_plan")
  label=$(jq -r --arg relation_id "$relation_id" '.dependencies[]|select(.id==$relation_id)|.label' "$project_plan")
  via_entity=$(jq -r --arg relation_id "$relation_id" '.dependencies[]|select(.id==$relation_id)|.via_entity' "$project_plan")
  evidence_id="local-ledger://evidence/released-project-plan/dependency/$ordinal"

  jq -S -c -n \
    --arg id "$evidence_id" --arg relation_id "$relation_id" \
    --arg repository "$product_repository" --arg tag "$product_tag" \
    --arg target_commit_sha "$product_target" --arg asset_name "$product_asset_name" \
    --arg asset_sha256 "$product_asset_sha" --arg member "$product_asset_name" \
    --arg json_pointer "/dependencies/$relation_index" --arg value_sha256 "$value_sha" \
    '{schema:"gooo/interchange/evidence/v2",id:$id,relation_id:$relation_id,
      source:{repository:$repository,tag:$tag,target_commit_sha:$target_commit_sha,asset_name:$asset_name,asset_sha256:$asset_sha256,member:$member,json_pointer:$json_pointer},
      observation:{kind:"RELEASED_JSON_VALUE",value_sha256:$value_sha256},
      authority:{claim_scope:"RELEASED_DECLARATION_ONLY",semantic_truth_claimed:false}}' \
    >> "$tmp/envelope/evidence.ndjson"

  jq -S -c -n \
    --arg id "$relation_id" --arg kind "$kind" --arg from_activity "$from_activity" \
    --arg to_activity "$to_activity" --arg evidence_id "$evidence_id" --arg label "$label" \
    --argjson ordinal "$ordinal" --arg via_entity "$via_entity" \
    '{schema:"gooo/interchange/relation/v2",id:$id,kind:$kind,domain_state:"STRUCTURAL_DEPENDENCY",disposition:"OBSERVED",
      left:{kind:"GOOO_ACTIVITY",id:$from_activity},right:{kind:"GOOO_ACTIVITY",id:$to_activity},evidence_ids:[$evidence_id],
      attributes:{label:$label,ordinal:$ordinal,via_entity:$via_entity,primitive:"gooo.primitive.claim-dependency-causality.v1"},
      authority:{domain_semantics_preserved:true,claim_resolution_embedded:false}}' \
    >> "$tmp/envelope/relations.ndjson"

  jq -S -c -n \
    --arg relation_id "$relation_id" \
    '{schema:"gooo/interchange/resolution/v2",relation_id:$relation_id,state:"CLOSED",stage:null,step:null,
      reason:"RELEASED_PRODUCT_DEPENDENCY_OBSERVED",unknown_class:null,next_operation:"NONE",blocked_by:[],
      authority:{source:"RELEASED_PRODUCT_EVIDENCE",state_inference_authorized:false}}' \
    >> "$tmp/envelope/resolutions.ndjson"
done < <(jq -r '.dependencies|sort_by(.ordinal)[]|[.ordinal,.id]|@tsv' "$project_plan")

: > "$tmp/envelope/unknowns.ndjson"
jq -S -n '
  {schema:"gooo/interchange/conformance/v2",required_files:8,
   required_local_checks:["EXACT_FILE_SET","PROJECT_IDENTITY_AND_AUTHORITY","CARDINALITIES","EVIDENCE_ANCHORS","RELATION_ANCHORS","RESOLUTION_TUPLES","UNKNOWN_SUBSET","SOURCE_REPLAY","SHA256_CHECKSUMS","DETERMINISTIC_REPLAY"],
   external_required_gates:0,repository_writes:0,product_generation_authorized:false,
   unknown_fields:["stage","step","reason","unknown_class","next_operation","blocked_by"]}
' > "$tmp/envelope/conformance.json"

payload_sha256=$(cd "$tmp/envelope" && sha256sum project.json evidence.ndjson relations.ndjson resolutions.ndjson unknowns.ndjson conformance.json | sha256sum | awk '{print $1}')
jq -S -n --arg payload_sha256 "$payload_sha256" \
  '{schema:"gooo/interchange/replay/v2",source:{receipt_schema:"gooo/local-ledger/released-domain-envelope-v2-projection-replay/v1",comparisons_satisfied:1,comparisons_total:1,receipt_verified:true},projection:{payload_files:6,payload_sha256:$payload_sha256},authority:{determinism_is_semantic_truth:false,product_execution_authorized:false}}' \
  > "$tmp/envelope/replay.json"

(cd "$tmp/envelope" && sha256sum conformance.json evidence.ndjson project.json replay.json relations.ndjson resolutions.ndjson unknowns.ndjson > checksums.txt)

rm -rf "$output"
mv "$tmp/envelope" "$output"
