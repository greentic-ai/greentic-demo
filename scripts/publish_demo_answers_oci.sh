#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname "$0")/.." && pwd)
DEMOS_DIR="${DEMOS_DIR:-$ROOT_DIR/demos}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-$ROOT_DIR/.artifacts}"
OWNER="${OWNER:?OWNER is required}"
TAG="${TAG:-}"
PUBLISH_LATEST="${PUBLISH_LATEST:-0}"
ANSWER_HELPER="$ROOT_DIR/scripts/lib/demo_answer_artifacts.py"

require_command() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "$command_name not found; cannot publish demo answer OCI artifacts." >&2
        exit 1
    fi
}

matches_filter() {
    local file="$1"
    local demo="$2"
    local filter
    if [ "$#" -le 2 ]; then
        return 0
    fi

    shift 2
    for filter in "$@"; do
        if [[ "$filter" == *.json ]]; then
            if [[ "$file" == "$filter" || "$ROOT_DIR/$file" == "$filter" || "$(basename "$file")" == "$(basename "$filter")" ]]; then
                return 0
            fi
        elif [[ "$demo" == "$filter" ]]; then
            return 0
        fi
    done
    return 1
}

require_command oras
require_command jq
require_command python3

if [[ -z "$TAG" ]]; then
    TAG="$(git -C "$ROOT_DIR" rev-parse HEAD)"
fi

publish_tags=("$TAG")
if [[ "$PUBLISH_LATEST" == "1" && "$TAG" != "latest" ]]; then
    publish_tags+=("latest")
fi

mkdir -p "$ARTIFACTS_DIR"
: > "$ARTIFACTS_DIR/answer-refs.txt"
mapfile -t answer_rows < <(cd "$ROOT_DIR" && python3 "$ANSWER_HELPER" list "$DEMOS_DIR")
published=0

for row in "${answer_rows[@]}"; do
    IFS=$'\t' read -r file demo artifact media_type <<< "$row"
    if ! matches_filter "$file" "$demo" "$@"; then
        continue
    fi

    if [ ! -f "$ROOT_DIR/$file" ] && [ ! -f "$file" ]; then
        echo "Answer artifact file not found: $file" >&2
        exit 1
    fi
    answer_file="$file"
    [ -f "$answer_file" ] || answer_file="$ROOT_DIR/$file"

    jq -e 'type == "object"' "$answer_file" >/dev/null
    python3 "$ANSWER_HELPER" validate "$answer_file"

    for tag in "${publish_tags[@]}"; do
        ref="ghcr.io/${OWNER}/answers/${demo}/${artifact}:${tag}"
        echo "Publishing ${answer_file} -> ${ref}"
        oras push --disable-path-validation --artifact-type "$media_type" "$ref" "${answer_file}:${media_type}"
        echo "${demo}_${artifact}_${tag}=oci://${ref}" >> "$ARTIFACTS_DIR/answer-refs.txt"
        echo "oci://${ref}"
        published=1
    done
done

if [ "$published" -eq 0 ]; then
    echo "No answer artifacts matched." >&2
    exit 1
fi
