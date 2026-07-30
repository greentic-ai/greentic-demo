#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname "$0")/.." && pwd)
DEMOS_DIR="${DEMOS_DIR:-$ROOT_DIR/demos}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-$ROOT_DIR/.artifacts}"
OWNER="${OWNER:?OWNER is required}"
TAG="${TAG:-}"
PUBLISH_LATEST="${PUBLISH_LATEST:-0}"
PACK_MEDIA_TYPE="application/vnd.greentic.gtpack.v1+zip"
# See publish_demo_artifacts_oci.sh: GHCR links a package to a repository from
# this annotation, and an unlinked package is neither writable by CI nor
# publicly pullable.
SOURCE_REPO_URL="${SOURCE_REPO_URL:-https://github.com/${GITHUB_REPOSITORY:-${OWNER}/greentic-demo}}"

require_command() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "$command_name not found; cannot publish demo pack OCI artifacts." >&2
        exit 1
    fi
}

require_command oras

if [[ -z "$TAG" ]]; then
    TAG="$(git -C "$ROOT_DIR" rev-parse HEAD)"
fi

publish_tags=("$TAG")
if [[ "$PUBLISH_LATEST" == "1" && "$TAG" != "latest" ]]; then
    publish_tags+=("latest")
fi

mkdir -p "$ARTIFACTS_DIR"
: > "$ARTIFACTS_DIR/pack-refs.txt"
shopt -s nullglob
if [ "$#" -gt 0 ]; then
    packs=("$@")
else
    packs=("$DEMOS_DIR"/*.gtpack)
fi

if [ ${#packs[@]} -eq 0 ]; then
    echo "No demo pack artifacts found." >&2
    exit 1
fi

for pack_path in "${packs[@]}"; do
    if [ ! -f "$pack_path" ]; then
        echo "Pack artifact not found: $pack_path" >&2
        exit 1
    fi

    pack_name="$(basename "$pack_path" .gtpack)"
    for tag in "${publish_tags[@]}"; do
        ref="ghcr.io/${OWNER}/packs/demos/${pack_name}:${tag}"
        echo "Publishing ${pack_path} -> ${ref}"
        oras push --disable-path-validation \
            --annotation "org.opencontainers.image.source=${SOURCE_REPO_URL}" \
            --artifact-type "$PACK_MEDIA_TYPE" "$ref" "${pack_path}:${PACK_MEDIA_TYPE}"
        echo "${pack_name}_${tag}=oci://${ref}" >> "$ARTIFACTS_DIR/pack-refs.txt"
        echo "oci://${ref}"
    done
done
