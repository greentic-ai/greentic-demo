#!/usr/bin/env bash
# Mirrors the GitHub Actions workflow locally.
# Examples:
#   ci/local_check.sh
#   LOCAL_CHECK_STRICT=1 LOCAL_CHECK_VERBOSE=1 ci/local_check.sh

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

LOCAL_CHECK_STRICT=${LOCAL_CHECK_STRICT:-0}
LOCAL_CHECK_VERBOSE=${LOCAL_CHECK_VERBOSE:-0}

if [ "$LOCAL_CHECK_VERBOSE" = "1" ]; then
    set -x
fi

need() {
    command -v "$1" >/dev/null 2>&1
}

hard_need() {
    if ! need "$1"; then
        echo "[error] required tool '$1' is missing" >&2
        exit 1
    fi
}

step() {
    echo ""
    echo "▶ $*"
}

run_cmd() {
    local desc=$1
    shift
    step "$desc"
    if ! "$@"; then
        echo "[fail] $desc" >&2
        exit 1
    fi
}

hard_need rustc
hard_need cargo

step "Tool versions"
rustc --version
cargo --version

run_cmd "cargo fmt" cargo fmt --all -- --check
run_cmd "cargo clippy" cargo clippy --workspace --all-targets --all-features --locked -- -D warnings
run_cmd "cargo test" cargo test --workspace --locked -- --nocapture
run_cmd "cargo package (greentic-runner-host)" bash -c 'cd crates/greentic-runner-host && cargo package --allow-dirty'

if grep -q 'greentic-runner-host' Cargo.toml && grep -A2 'greentic-runner-host' Cargo.toml | grep -q 'path'; then
    echo "[skip] cargo package (greentic-demo) because greentic-runner-host is still a path dependency"
else
    run_cmd "cargo package (greentic-demo)" cargo package --allow-dirty
fi

echo ""
echo "local_check: all checks passed"
