#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname "$0")" && pwd)
COMPONENT_DIR="$ROOT_DIR/component-telco-present"
STAGE_DIR="$ROOT_DIR/generated-pack/components/component-telco-present"

mkdir -p "$STAGE_DIR"

# component-telco-present depends on two private sibling repos (telco-x,
# greentic-messaging-providers) checked out next to this one — they're not
# part of this repo and aren't available in CI or a fresh clone. The
# component.wasm/component.manifest.json committed under generated-pack/ are
# the source of truth for packaging; only rebuild when explicitly asked to
# (i.e. a maintainer who actually has those sibling repos checked out and
# wants to pick up a source change), so `cargo component` merely being
# present on PATH doesn't force a doomed rebuild attempt.
if [ "${TELCO_PRESENT_FORCE_REBUILD:-}" != "1" ]; then
  if [ -f "$STAGE_DIR/component.wasm" ] && [ -f "$STAGE_DIR/component.manifest.json" ]; then
    exit 0
  fi
fi

if ! cargo component --version >/dev/null 2>&1; then
  echo "cargo component is required to build telco-x-demo component" >&2
  exit 1
fi

cargo component build \
  --release \
  --target wasm32-wasip2 \
  --manifest-path "$COMPONENT_DIR/Cargo.toml" >/dev/null

cp "$COMPONENT_DIR/target/wasm32-wasip2/release/component_telco_present.wasm" "$STAGE_DIR/component.wasm"
cp "$COMPONENT_DIR/component.manifest.json" "$STAGE_DIR/component.manifest.json"
