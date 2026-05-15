#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname "$0")/.." && pwd)
DEMOS_DIR="${DEMOS_DIR:-$ROOT_DIR/demos}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-$ROOT_DIR/.artifacts}"
OWNER="${OWNER:?OWNER is required}"
SHA="${SHA:?SHA is required}"
REF_NAME="${REF_NAME:-}"
REF_TYPE="${REF_TYPE:-}"
BRANCH_NAME="${BRANCH_NAME:-$REF_NAME}"
PUBLISH_VERSION="${PUBLISH_VERSION:-}"
PUBLISH_BUNDLES="${PUBLISH_BUNDLES:-0}"
ANSWER_HELPER="$ROOT_DIR/scripts/lib/demo_answer_artifacts.py"
PACK_MEDIA_TYPE="application/vnd.greentic.gtpack.v1+zip"

require_command() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "$command_name not found; cannot publish demo OCI artifacts." >&2
        exit 1
    fi
}

append_unique_tag() {
    local tag="$1"
    local existing
    [ -n "$tag" ] || return 0
    for existing in "${publish_tags[@]}"; do
        [ "$existing" = "$tag" ] && return 0
    done
    publish_tags+=("$tag")
}

publish_ref() {
    local ref="$1"
    local file="$2"
    local media_type="$3"

    oras push --disable-path-validation --artifact-type "$media_type" "$ref" "${file}:${media_type}"
    echo "  -> ${ref}"
}

require_command oras
require_command jq
require_command python3

mkdir -p "$ARTIFACTS_DIR"
: > "$ARTIFACTS_DIR/pack-refs.txt"
: > "$ARTIFACTS_DIR/answer-refs.txt"
if [[ "$PUBLISH_BUNDLES" == "1" ]]; then
    : > "$ARTIFACTS_DIR/bundle-refs.txt"
fi

publish_tags=()
append_unique_tag "$SHA"
if [[ "$BRANCH_NAME" == "main" || "$BRANCH_NAME" == "master" || "$REF_NAME" == "main" || "$REF_NAME" == "master" ]]; then
    append_unique_tag "latest"
fi
append_unique_tag "$PUBLISH_VERSION"

shopt -s nullglob
packs=("$DEMOS_DIR"/*.gtpack)
bundles=("$DEMOS_DIR"/*.gtbundle)
mapfile -t answer_rows < <(cd "$ROOT_DIR" && python3 "$ANSWER_HELPER" list "$DEMOS_DIR")

if [ ${#packs[@]} -eq 0 ] && [ ${#answer_rows[@]} -eq 0 ] && { [[ "$PUBLISH_BUNDLES" != "1" ]] || [ ${#bundles[@]} -eq 0 ]; }; then
    echo "No demo packs or answer artifacts found under $DEMOS_DIR. Nothing to publish."
    exit 0
fi

for pack_path in "${packs[@]}"; do
    pack_name="$(basename "$pack_path" .gtpack)"
    echo "Publishing ${pack_name} pack..."
    for tag in "${publish_tags[@]}"; do
        ref="ghcr.io/${OWNER}/packs/demos/${pack_name}:${tag}"
        publish_ref "$ref" "$pack_path" "$PACK_MEDIA_TYPE"
        echo "${pack_name}_${tag}=oci://${ref}" >> "$ARTIFACTS_DIR/pack-refs.txt"
    done
done

for row in "${answer_rows[@]}"; do
    IFS=$'\t' read -r file demo artifact media_type <<< "$row"
    if [ ! -f "$ROOT_DIR/$file" ] && [ ! -f "$file" ]; then
        echo "Answer artifact file not found: $file" >&2
        exit 1
    fi
    answer_file="$file"
    [ -f "$answer_file" ] || answer_file="$ROOT_DIR/$file"

    jq -e 'type == "object"' "$answer_file" >/dev/null
    python3 "$ANSWER_HELPER" validate "$answer_file"

    echo "Publishing ${demo}/${artifact} answers..."
    for tag in "${publish_tags[@]}"; do
        ref="ghcr.io/${OWNER}/answers/${demo}/${artifact}:${tag}"
        publish_ref "$ref" "$answer_file" "$media_type"
        echo "${demo}_${artifact}_${tag}=oci://${ref}" >> "$ARTIFACTS_DIR/answer-refs.txt"
    done
done

if [[ "$PUBLISH_BUNDLES" == "1" ]]; then
    for bundle_path in "${bundles[@]}"; do
        bundle_name="$(basename "$bundle_path" .gtbundle)"
        media_type="application/vnd.greentic.${bundle_name}.bundle.v1+tar+gzip"
        echo "Publishing ${bundle_name} bundle..."
        for tag in "${publish_tags[@]}"; do
            ref="ghcr.io/${OWNER}/bundles/${bundle_name}:${tag}"
            publish_ref "$ref" "$bundle_path" "$media_type"
            echo "${bundle_name}_${tag}=oci://${ref}" >> "$ARTIFACTS_DIR/bundle-refs.txt"
        done
    done
else
    echo "Skipping demo bundle publication; set PUBLISH_BUNDLES=1 to enable it."
fi
