#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 4; then
  echo "usage: project-readiness-claim.sh REPORT READINESS_DENOMINATOR UNKNOWN_CLASSIFICATION OUTPUT_DIRECTORY" >&2
  exit 2
fi

report=$1
denominator=$2
classification=$3
output=$4
mkdir -p "$output"
projection="$output/projection.json"
source="$output/projected-claim.gooo"

report_digest=UNAVAILABLE
test -f "$report" && report_digest=$(sha256sum "$report" | awk '{print "sha256:" $1}')
denominator_id=$(jq -r '.id // "UNKNOWN"' "$denominator" 2>/dev/null || printf 'UNKNOWN')
classification_id=$(jq -r '.id // "UNKNOWN"' "$classification" 2>/dev/null || printf 'UNKNOWN')
input_phase=$(jq -r '.phase // "UNKNOWN"' "$report" 2>/dev/null || printf 'UNKNOWN')

emit_refuted() {
  reason=$1
  next_operation=$2
  jq -S -n \
    --arg report_digest "$report_digest" \
    --arg denominator_id "$denominator_id" \
    --arg classification_id "$classification_id" \
    --arg input_phase "$input_phase" \
    --arg reason "$reason" \
    --arg next_operation "$next_operation" '
    {
      schema:"gooo/local-ledger/readiness-claim-projection/v1",
      decision:"FAIL_CLOSED",
      input:{phase:$input_phase,report_digest:$report_digest,denominator_id:$denominator_id,classification_id:$classification_id},
      claim:{state:"REFUTED",stage:"CLASSIFICATION",step:"PROJECT_READINESS_CLAIM",reason:$reason,unknown_class:null,next_operation:$next_operation},
      generated_claim_programs:0,projected_tuple_fields:0,repository_writes:0
    }
  ' > "$projection"
  exit 3
}

for file in "$report" "$denominator" "$classification"; do
  test -f "$file" || emit_refuted "PROJECTION_INPUT_UNAVAILABLE" "PROVIDE_PROJECTION_INPUTS"
done

jq -e '
  .schema=="gooo/local-ledger/readiness-denominator/v1" and
  .id=="gooo://denominator/local-ledger-release-readiness-v1" and
  .target_cells==12 and (.cells|length)==12 and
  ([.cells[].id]|unique|length)==12
' "$denominator" >/dev/null || emit_refuted "READINESS_DENOMINATOR_INVALID" "RESTORE_READINESS_DENOMINATOR"

jq -e '
  .schema=="gooo/local-ledger/readiness-unknown-classification/v1" and
  .id=="gooo://classification/local-ledger-readiness-unknown-v1" and
  .total==12 and (.classes|length)==12 and
  all(.classes[]; (.unknown_class=="DIRECT_MISSING" or .unknown_class=="CONTEXT_MISSING" or .unknown_class=="DEPENDENCY_BLOCKED"))
' "$classification" >/dev/null || emit_refuted "UNKNOWN_CLASSIFICATION_INVALID" "RESTORE_UNKNOWN_CLASSIFICATION"

unique_ids=$(jq '[.classes[].id]|unique|length' "$classification")
test "$unique_ids" -eq 12 || emit_refuted "UNKNOWN_CLASSIFICATION_ID_DUPLICATED" "RESTORE_CLASSIFICATION_BIJECTION"
unique_coordinates=$(jq '[.classes[]|[.stage,.step,.reason,.next_operation]|join("|")]|unique|length' "$classification")
test "$unique_coordinates" -eq 12 || emit_refuted "UNKNOWN_CLASSIFICATION_COORDINATE_DUPLICATED" "RESTORE_CLASSIFICATION_BIJECTION"

jq -e --slurpfile denominator "$denominator" '
  .source_denominator_id==$denominator[0].id and
  ([.classes[] as $class |
    $denominator[0].cells[] |
    select(.id==$class.id and .stage==$class.stage and .step==$class.step and
      .unknown_reason==$class.reason and .next_operation==$class.next_operation)
  ]|length)==12
' "$classification" >/dev/null || emit_refuted "UNKNOWN_CLASSIFICATION_DENOMINATOR_MISMATCH" "RESTORE_CLASSIFICATION_BIJECTION"

jq -e '
  .schema=="gooo/local-ledger/readiness-report/v1" and
  (.claim|type)=="object" and
  (
    (.claim.state=="CLOSED" and .decision=="RELEASE_READY" and .claim.stage==null and .claim.step==null) or
    (.claim.state=="UNKNOWN" and .decision=="NOT_READY" and (.claim.stage|type)=="string" and (.claim.step|type)=="string") or
    (.claim.state=="REFUTED" and .decision=="FAIL_CLOSED" and (.claim.stage|type)=="string" and (.claim.step|type)=="string")
  ) and (.claim.reason|type)=="string" and (.claim.next_operation|type)=="string"
' "$report" >/dev/null || emit_refuted "READINESS_REPORT_INVALID" "RESTORE_RELEASED_READINESS_REPORT"

state=$(jq -r '.claim.state' "$report")
stage=$(jq -r '.claim.stage // "NONE"' "$report")
step=$(jq -r '.claim.step // "NONE"' "$report")
reason=$(jq -r '.claim.reason' "$report")
next_operation=$(jq -r '.claim.next_operation' "$report")
unknown_class=NONE
classification_match_count=0

if test "$state" = UNKNOWN; then
  classification_match_count=$(jq \
    --arg stage "$stage" --arg step "$step" --arg reason "$reason" --arg next "$next_operation" \
    '[.classes[]|select(.stage==$stage and .step==$step and .reason==$reason and .next_operation==$next)]|length' \
    "$classification")
  test "$classification_match_count" -gt 0 || emit_refuted "UNKNOWN_COORDINATE_UNDECLARED" "DECLARE_UNKNOWN_COORDINATE"
  test "$classification_match_count" -eq 1 || emit_refuted "UNKNOWN_COORDINATE_AMBIGUOUS" "RESTORE_CLASSIFICATION_BIJECTION"
  unknown_class=$(jq -r \
    --arg stage "$stage" --arg step "$step" --arg reason "$reason" --arg next "$next_operation" \
    '.classes[]|select(.stage==$stage and .step==$step and .reason==$reason and .next_operation==$next)|.unknown_class' \
    "$classification")
fi

token_pattern='^(NONE|[A-Z][A-Z0-9_]*)$'
for token in "$state" "$stage" "$step" "$reason" "$unknown_class" "$next_operation"; do
  [[ "$token" =~ $token_pattern ]] || emit_refuted "CLAIM_TOKEN_NOT_CANONICAL" "RESTORE_CANONICAL_CLAIM_TOKEN"
done

cat > "$source" <<EOF
package projectedreadinessclaim
namespace localreadinessprojection

entity ClaimInput id "local://readiness-projection/claim-input"
entity ClaimResolutionPrimitive id "gooo://claim-resolution/gooo.primitive.claim-resolution-tuple.v1"

activity ResolveProjectedReadinessClaim(ClaimInput) -> ClaimResolutionPrimitive computes "claim.resolve:v1;state=$state;stage=$stage;step=$step;reason=$reason;unknown_class=$unknown_class;next_operation=$next_operation"
EOF

source_digest=$(sha256sum "$source" | awk '{print "sha256:" $1}')
jq -S -n \
  --arg report_digest "$report_digest" \
  --arg denominator_id "$denominator_id" \
  --arg classification_id "$classification_id" \
  --arg input_phase "$input_phase" \
  --arg state "$state" --arg stage "$stage" --arg step "$step" --arg reason "$reason" \
  --arg unknown_class "$unknown_class" --arg next_operation "$next_operation" \
  --arg source_digest "$source_digest" --argjson classification_match_count "$classification_match_count" '
  {
    schema:"gooo/local-ledger/readiness-claim-projection/v1",
    decision:"READINESS_CLAIM_PROGRAM_PROJECTED",
    input:{phase:$input_phase,report_digest:$report_digest,denominator_id:$denominator_id,classification_id:$classification_id},
    claim:{state:$state,stage:(if $stage=="NONE" then null else $stage end),step:(if $step=="NONE" then null else $step end),
      reason:$reason,unknown_class:(if $unknown_class=="NONE" then null else $unknown_class end),next_operation:$next_operation},
    generated_source:{name:"projected-claim.gooo",digest:$source_digest,activity:"ResolveProjectedReadinessClaim"},
    generated_claim_programs:1,projected_tuple_fields:6,classification_match_count:$classification_match_count,
    repository_writes:0
  }
' > "$projection"
