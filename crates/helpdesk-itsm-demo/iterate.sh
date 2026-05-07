#!/usr/bin/env bash
# Iteration helper for helpdesk-itsm-demo: rebuild pack from build-answer.json
# and drop it into the existing demo bundle, then restart and tail logs.
#
# Usage:
#   ./iterate.sh              # rebuild + restart + tail
#   ./iterate.sh build        # rebuild only
#   ./iterate.sh restart      # restart bundle only
#   BUNDLE=/path/to/bundle ./iterate.sh   # override bundle path

set -euo pipefail

CRATE_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE="${BUNDLE:-$HOME/Documents/Freelance/rebuilt}"
WORK="${TMPDIR:-/tmp}/helpdesk-itsm-build"
PACK_DIR="$WORK/helpdesk-itsm.pack"
PACK_OUT="$PACK_DIR/dist/helpdesk-itsm.pack.gtpack"
TARGET_PACK="$BUNDLE/packs/helpdesk-itsm.gtpack"

step() { printf '\n>>> %s\n' "$*"; }

build_pack() {
  step "extracting pack_create from build-answer.json"
  rm -rf "$WORK" && mkdir -p "$WORK"
  jq '.pack_create' "$CRATE_DIR/build-answer.json" > "$WORK/pack-create.json"

  step "running pack-create wizard (scaffold + flow wizard via run_delegate_flow=true)"
  ( cd "$WORK" && greentic-pack wizard apply --answers "$WORK/pack-create.json" )

  step "overlaying crate assets onto pack source"
  cp -R "$CRATE_DIR/assets/." "$PACK_DIR/assets/"

  step "running pack update wizard (validate)"
  jq '.pack' "$CRATE_DIR/build-answer.json" > "$WORK/pack-update.json"
  ( cd "$PACK_DIR" && greentic-pack wizard apply --answers "$WORK/pack-update.json" )

  step "building .gtpack artifact"
  ( cd "$PACK_DIR" && greentic-pack build --in . )

  if [[ ! -f "$PACK_OUT" ]]; then
    PACK_OUT="$(ls "$PACK_DIR"/dist/*.gtpack 2>/dev/null | head -1 || true)"
  fi
  [[ -f "$PACK_OUT" ]] || { echo "ERROR: no .gtpack produced under $PACK_DIR/dist/" >&2; ls -la "$PACK_DIR/dist" 2>&1; exit 1; }

  step "inspecting rebuilt pack"
  unzip -l "$PACK_OUT" | head -40

  step "copying $PACK_OUT -> $TARGET_PACK"
  cp "$PACK_OUT" "$TARGET_PACK"
}

restart_bundle() {
  step "killing anything on :8080"
  lsof -ti:8080 | xargs kill -9 2>/dev/null || true
  sleep 1
  step "truncating logs"
  : > "$BUNDLE/logs/operator.log"
  : > "$BUNDLE/logs/flow.log"
  step "starting bundle (background)"
  ( cd "$(dirname "$BUNDLE")" && nohup gtc start "./$(basename "$BUNDLE")" >/tmp/gtc-start.out 2>&1 & )
  sleep 8
}

tail_logs() {
  step "operator.log highlights"
  grep -E "offers_total|packs_total|messaging pipeline failed|select app|APP_FLOW|app flow=" \
    "$BUNDLE/logs/operator.log" | tail -20 || true
  step "flow.log size"
  wc -l "$BUNDLE/logs/flow.log"
}

case "${1:-all}" in
  build)   build_pack ;;
  restart) restart_bundle; tail_logs ;;
  tail)    tail_logs ;;
  all|"")  build_pack; restart_bundle; tail_logs ;;
  *) echo "Usage: $0 [build|restart|tail|all]" >&2; exit 1 ;;
esac
