#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname "$0")/.." && pwd)
TMP_ROOT="${TMPDIR:-/tmp}/publish-demo-oci-test.$$"

cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

mkdir -p "$TMP_ROOT/demos" "$TMP_ROOT/bin" "$TMP_ROOT/artifacts"

cat > "$TMP_ROOT/demos/foo-create-answers.json" <<'JSON'
{"answers":{}}
JSON
cat > "$TMP_ROOT/demos/foo-setup-answers.json" <<'JSON'
{"setup_answers":{}}
JSON
printf 'gtpack' > "$TMP_ROOT/demos/foo.gtpack"
printf 'gtbundle' > "$TMP_ROOT/demos/foo.gtbundle"
cat > "$TMP_ROOT/demos/demo-artifacts.json" <<JSON
{
  "answers": [
    {
      "demo": "foo",
      "file": "$TMP_ROOT/demos/foo-create-answers.json",
      "artifact": "create",
      "media_type": "application/vnd.greentic.answers.create.v1+json"
    },
    {
      "demo": "foo",
      "file": "$TMP_ROOT/demos/foo-setup-answers.json",
      "artifact": "setup",
      "media_type": "application/vnd.greentic.answers.setup.v1+json"
    }
  ]
}
JSON

cat > "$TMP_ROOT/bin/oras" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$ORAS_LOG"
SH
chmod +x "$TMP_ROOT/bin/oras"

ORAS_LOG="$TMP_ROOT/oras.log" \
PATH="$TMP_ROOT/bin:$PATH" \
OWNER=greenticai \
TAG=dev-test \
DEMOS_DIR="$TMP_ROOT/demos" \
ARTIFACTS_DIR="$TMP_ROOT/artifacts" \
"$ROOT_DIR/scripts/publish_demo_answers_oci.sh" foo >/dev/null

grep -Fq "ghcr.io/greenticai/answers/foo/create:dev-test" "$TMP_ROOT/oras.log"
grep -Fq "foo-create-answers.json:application/vnd.greentic.answers.create.v1+json" "$TMP_ROOT/oras.log"
grep -Fq "ghcr.io/greenticai/answers/foo/setup:dev-test" "$TMP_ROOT/oras.log"
grep -Fq "foo_setup_dev-test=oci://ghcr.io/greenticai/answers/foo/setup:dev-test" "$TMP_ROOT/artifacts/answer-refs.txt"

: > "$TMP_ROOT/oras.log"
ORAS_LOG="$TMP_ROOT/oras.log" \
PATH="$TMP_ROOT/bin:$PATH" \
OWNER=greenticai \
TAG=dev-test \
DEMOS_DIR="$TMP_ROOT/demos" \
ARTIFACTS_DIR="$TMP_ROOT/artifacts" \
"$ROOT_DIR/scripts/publish_demo_packs_oci.sh" "$TMP_ROOT/demos/foo.gtpack" >/dev/null

grep -Fq "ghcr.io/greenticai/packs/demos/foo:dev-test" "$TMP_ROOT/oras.log"
grep -Fq "foo.gtpack:application/vnd.greentic.gtpack.v1+zip" "$TMP_ROOT/oras.log"
grep -Fq "foo_dev-test=oci://ghcr.io/greenticai/packs/demos/foo:dev-test" "$TMP_ROOT/artifacts/pack-refs.txt"

: > "$TMP_ROOT/oras.log"
ORAS_LOG="$TMP_ROOT/oras.log" \
PATH="$TMP_ROOT/bin:$PATH" \
OWNER=greenticai \
SHA=abc123 \
BRANCH_NAME=main \
DEMOS_DIR="$TMP_ROOT/demos" \
ARTIFACTS_DIR="$TMP_ROOT/artifacts" \
"$ROOT_DIR/scripts/publish_demo_artifacts_oci.sh" >/dev/null

grep -Fq "ghcr.io/greenticai/packs/demos/foo:abc123" "$TMP_ROOT/oras.log"
grep -Fq "ghcr.io/greenticai/packs/demos/foo:latest" "$TMP_ROOT/oras.log"
grep -Fq "ghcr.io/greenticai/answers/foo/create:abc123" "$TMP_ROOT/oras.log"
grep -Fq "ghcr.io/greenticai/answers/foo/create:latest" "$TMP_ROOT/oras.log"
if grep -Fq "ghcr.io/greenticai/bundles/foo" "$TMP_ROOT/oras.log"; then
    echo "bundle was published even though PUBLISH_BUNDLES was not enabled" >&2
    exit 1
fi

mkdir -p "$TMP_ROOT/no-oras-bin"
ln -s "$(command -v jq)" "$TMP_ROOT/no-oras-bin/jq"
ln -s "$(command -v python3)" "$TMP_ROOT/no-oras-bin/python3"
if PATH="$TMP_ROOT/no-oras-bin" \
    OWNER=greenticai \
    TAG=dev-test \
    DEMOS_DIR="$TMP_ROOT/demos" \
    ARTIFACTS_DIR="$TMP_ROOT/artifacts" \
    /bin/bash "$ROOT_DIR/scripts/publish_demo_answers_oci.sh" foo >"$TMP_ROOT/missing-oras.out" 2>&1; then
    echo "expected missing oras failure" >&2
    exit 1
fi
grep -Fq "oras not found" "$TMP_ROOT/missing-oras.out"

echo "publish demo OCI script tests passed"
