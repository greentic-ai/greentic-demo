#!/usr/bin/env bash

# Verify that every published answers artifact is reachable the way a user
# reaches it: anonymously, with no credentials at all.
#
# `gtc wizard --answers oci://ghcr.io/<owner>/answers/<demo>/<artifact>:<tag>`
# is the advertised one-line entry point for every demo. A GHCR package that is
# private, or that was created without the org.opencontainers.image.source
# annotation and therefore never linked to this repository, fails that pull —
# while the publish job itself still reports success, because pushing and
# anonymous pulling are different permissions. Four answer packages sat broken
# and unnoticed for three weeks that way.
#
# Usage: OWNER=greenticai [TAG=latest] scripts/verify_public_answer_refs.sh

set -uo pipefail

ROOT_DIR=$(cd -- "$(dirname "$0")/.." && pwd)
DEMOS_DIR="${DEMOS_DIR:-$ROOT_DIR/demos}"
OWNER="${OWNER:?OWNER is required}"
TAG="${TAG:-latest}"
ANSWER_HELPER="$ROOT_DIR/scripts/lib/demo_answer_artifacts.py"

for command_name in curl jq python3; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "$command_name not found; cannot verify published answer refs." >&2
        exit 1
    fi
done

# Deliberately unauthenticated: ghcr.io hands out an anonymous pull token for
# public packages and refuses for private ones, which is exactly the signal we
# want. Never add credentials here — that would make the check pass for
# packages real users cannot read.
probe_ref() {
    local repository="$1"
    local token http_code

    token=$(curl -sf --max-time 30 \
        "https://ghcr.io/token?scope=repository:${repository}:pull&service=ghcr.io" \
        | jq -r '.token // empty')
    if [ -z "$token" ]; then
        echo "no-anonymous-token"
        return
    fi

    http_code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 \
        -H "Authorization: Bearer ${token}" \
        -H "Accept: application/vnd.oci.image.manifest.v1+json" \
        -H "Accept: application/vnd.oci.artifact.manifest.v1+json" \
        "https://ghcr.io/v2/${repository}/manifests/${TAG}")
    echo "$http_code"
}

mapfile -t answer_rows < <(cd "$ROOT_DIR" && python3 "$ANSWER_HELPER" list "$DEMOS_DIR")
if [ "${#answer_rows[@]}" -eq 0 ]; then
    echo "No answer artifacts declared under $DEMOS_DIR; nothing to verify." >&2
    exit 1
fi

failures=0
checked=0
for row in "${answer_rows[@]}"; do
    IFS=$'\t' read -r _file demo artifact _media_type <<< "$row"
    repository="${OWNER}/answers/${demo}/${artifact}"
    result=$(probe_ref "$repository")
    checked=$((checked + 1))
    if [ "$result" = "200" ]; then
        printf '  ok       oci://ghcr.io/%s:%s\n' "$repository" "$TAG"
    else
        printf '  UNREADABLE (%s) oci://ghcr.io/%s:%s\n' "$result" "$repository" "$TAG" >&2
        failures=$((failures + 1))
    fi
done

if [ "$failures" -gt 0 ]; then
    cat >&2 <<EOF
::error::${failures}/${checked} answers artifact(s) are not anonymously pullable.
Each one is either private or not linked to a repository. Fix per package at
https://github.com/orgs/${OWNER}/packages -> Package settings:
  - Repository source must show ${OWNER}/greentic-demo (a push carrying the
    org.opencontainers.image.source annotation sets this automatically)
  - Danger Zone -> Change visibility -> Public
EOF
    exit 1
fi

echo "All ${checked} answers artifact(s) are anonymously pullable at :${TAG}."
