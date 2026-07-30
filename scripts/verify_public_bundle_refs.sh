#!/usr/bin/env bash

# Verify that every published `.gtbundle` artifact is reachable the way a
# deployer reaches it — anonymously, with no credentials — AND that the tag
# serves the bundle we just built.
#
# `op env apply` resolves a bundle from a `bundle_source_uri` of the form
# `oci://ghcr.io/<owner>/bundles/<bundle_id>:<tag>`, which is also what
# `gtc start <oci-ref> --target gcp` synthesizes. Two distinct failures have
# shipped here and neither one turns the publish job red:
#
#   1. Unreachable. Pushing and anonymous pulling are different permissions, so
#      a package that is private or was created without the
#      org.opencontainers.image.source annotation (and therefore never linked to
#      this repository) fails every user's pull while publish reports success.
#
#   2. Stale. Bundle publication is opt-in (`PUBLISH_BUNDLES=1`), so `:latest`
#      keeps serving whatever was pushed last. Between 2026-04-26 and the day
#      this check landed, every bundle tag served three-month-old content —
#      including one bundle that was a wizard workspace rather than a bundle at
#      all. Reachability alone said nothing about either problem, which is why
#      this compares digests instead of merely probing for a 200.
#
# oras pushes each `.gtbundle` as a single layer blob, so the layer descriptor's
# digest is the sha256 of the file itself. Comparing that against the local
# artifact proves content identity without downloading the blob back.
#
# Usage: OWNER=greenticai [TAG=latest] scripts/verify_public_bundle_refs.sh

set -uo pipefail

ROOT_DIR=$(cd -- "$(dirname "$0")/.." && pwd)
DEMOS_DIR="${DEMOS_DIR:-$ROOT_DIR/demos}"
OWNER="${OWNER:?OWNER is required}"
TAG="${TAG:-latest}"

for command_name in curl jq sha256sum; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "$command_name not found; cannot verify published bundle refs." >&2
        exit 1
    fi
done

# Deliberately unauthenticated: ghcr.io hands out an anonymous pull token for
# public packages and refuses for private ones, which is exactly the signal we
# want. Never add credentials here — that would make the check pass for
# packages real users cannot read.
fetch_manifest() {
    local repository="$1"
    local token

    token=$(curl -sf --max-time 30 \
        "https://ghcr.io/token?scope=repository:${repository}:pull&service=ghcr.io" \
        | jq -r '.token // empty')
    if [ -z "$token" ]; then
        return 1
    fi

    curl -sf --max-time 60 \
        -H "Authorization: Bearer ${token}" \
        -H "Accept: application/vnd.oci.image.manifest.v1+json" \
        -H "Accept: application/vnd.oci.artifact.manifest.v1+json" \
        "https://ghcr.io/v2/${repository}/manifests/${TAG}"
}

shopt -s nullglob
bundles=("$DEMOS_DIR"/*.gtbundle)
if [ "${#bundles[@]}" -eq 0 ]; then
    echo "No .gtbundle artifacts under $DEMOS_DIR; nothing to verify." >&2
    exit 1
fi

unreadable=0
stale=0
checked=0
for bundle_path in "${bundles[@]}"; do
    bundle_id="$(basename "$bundle_path" .gtbundle)"
    repository="${OWNER}/bundles/${bundle_id}"
    checked=$((checked + 1))

    manifest="$(fetch_manifest "$repository")"
    if [ -z "$manifest" ]; then
        printf '  UNREADABLE oci://ghcr.io/%s:%s\n' "$repository" "$TAG" >&2
        unreadable=$((unreadable + 1))
        continue
    fi

    published_digest="$(jq -r '.layers[0].digest // empty' <<<"$manifest")"
    local_digest="sha256:$(sha256sum "$bundle_path" | cut -d' ' -f1)"

    if [ "$published_digest" != "$local_digest" ]; then
        printf '  STALE      oci://ghcr.io/%s:%s\n' "$repository" "$TAG" >&2
        printf '               published %s\n' "${published_digest:-<none>}" >&2
        printf '               built     %s\n' "$local_digest" >&2
        stale=$((stale + 1))
        continue
    fi

    printf '  ok         oci://ghcr.io/%s:%s\n' "$repository" "$TAG"
done

if [ "$unreadable" -gt 0 ]; then
    cat >&2 <<EOF
::error::${unreadable}/${checked} bundle artifact(s) are not anonymously pullable.
Each one is either private or not linked to a repository. Fix per package at
https://github.com/orgs/${OWNER}/packages -> Package settings:
  - Repository source must show ${OWNER}/greentic-demo (a push carrying the
    org.opencontainers.image.source annotation sets this automatically)
  - Danger Zone -> Change visibility -> Public
EOF
fi

if [ "$stale" -gt 0 ]; then
    cat >&2 <<EOF
::error::${stale}/${checked} bundle tag(s) do not serve the bundle built in this run.
:${TAG} still points at an older push. Bundle publication is opt-in — re-run
Publish Demo Artifacts via workflow_dispatch with publish_bundles enabled.
EOF
fi

if [ "$unreadable" -gt 0 ] || [ "$stale" -gt 0 ]; then
    exit 1
fi

echo "All ${checked} bundle artifact(s) are anonymously pullable at :${TAG} and match this build."
