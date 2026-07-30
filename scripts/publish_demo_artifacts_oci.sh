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
# GHCR links a package to a repository from this annotation. Without it a
# brand-new package is created unlinked, which makes it unwritable by any
# repository's GITHUB_TOKEN on every later push and leaves it private, so
# `gtc wizard --answers oci://…` cannot pull it anonymously.
SOURCE_REPO_URL="${SOURCE_REPO_URL:-https://github.com/${GITHUB_REPOSITORY:-${OWNER}/greentic-demo}}"

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

# Brand-new GHCR packages that haven't been linked to this repo with write
# access yet surface as a permission denial on first push. That's an
# operator/infra condition, not a content bug — and with `set -e` the first
# such denial aborts the whole job, taking every later artifact down with it
# (e.g. pet-daycare-demo, the fast2flow routing / telemetry / fallback e2e
# showcase consumed by greentic-e2e). Treat write denials as a loud, non-fatal
# skip so the rest of the demos still publish; any other failure stays fatal.
SKIPPED_REFS=()
publish_ref() {
    local ref="$1"
    local file="$2"
    local media_type="$3"
    local out

    if out=$(oras push --disable-path-validation \
        --annotation "org.opencontainers.image.source=${SOURCE_REPO_URL}" \
        --artifact-type "$media_type" "$ref" "${file}:${media_type}" 2>&1); then
        echo "  -> ${ref}"
        return 0
    fi
    # GHCR does not always phrase a write denial as `permission_denied`. When the
    # package does not exist yet, oras probes for the blob first and the registry
    # answers the HEAD with a bare 403, e.g.
    #   Error response from registry: HEAD ".../blobs/sha256:…": response status code 403: Forbidden
    # which matched none of the patterns below, so the denial stayed fatal and
    # killed the job before the release step. Match the raw 403 too.
    if grep -qiE 'permission_denied|denied:.*write_package|insufficient_scope|requested access to the resource is denied|status code 403|403: *forbidden' <<<"$out"; then
        echo "::warning::skipping ${ref}: GHCR write denied (package not yet writable by this workflow)" >&2
        printf '%s\n' "$out" >&2
        SKIPPED_REFS+=("$ref")
        return 0
    fi
    echo "::error::failed to publish ${ref}" >&2
    printf '%s\n' "$out" >&2
    return 1
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

if [ ${#SKIPPED_REFS[@]} -gt 0 ]; then
    echo "::error::${#SKIPPED_REFS[@]} artifact ref(s) skipped due to GHCR write denial:" >&2
    for ref in "${SKIPPED_REFS[@]}"; do
        echo "  - ${ref}" >&2
    done
    echo "Grant the workflow write access to these GHCR packages to publish them." >&2
    # Deliberately fatal, but only after every other artifact has been pushed:
    # a warning here let four answer packages stay frozen at a 2026-07-07 commit
    # for three weeks while the job kept reporting success.
    exit 1
fi
