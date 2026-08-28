#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 1; then
  echo "usage: source-snapshot.sh CANDIDATE" >&2
  exit 2
fi

candidate=$1
manifest="$candidate/project.json"
test -f "$manifest"

(
  cd "$candidate"
  while IFS= read -r path; do
    test -f "$path" || { echo "missing source path: $path" >&2; exit 3; }
    printf '%s\0' "$path"
    sha256sum "$path" | awk '{printf "%s%c", $1, 0}'
  done < <(jq -r '.source_paths[]' project.json)
) | sha256sum | awk '{print "sha256:" $1}'
