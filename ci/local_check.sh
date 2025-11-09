#!/usr/bin/env bash
# Mirrors the GitHub Actions workflow locally.
# Examples:
#   ci/local_check.sh
#   LOCAL_CHECK_STRICT=1 LOCAL_CHECK_VERBOSE=1 ci/local_check.sh

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

export CARGO_HOME="${CARGO_HOME:-$ROOT_DIR/.cargo-home}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$ROOT_DIR/.target}"
export CARGO_NET_OFFLINE="${CARGO_NET_OFFLINE:-true}"
mkdir -p "$CARGO_HOME" "$CARGO_TARGET_DIR"

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

link_cargo_component() {
    local name=$1
    local src=$2
    local dst=$3
    local src_path="$src/$name"
    local dst_path="$dst/$name"
    if [ ! -e "$src_path" ]; then
        return
    fi
    if [ -L "$dst_path" ]; then
        local target
        target=$(readlink "$dst_path")
        if [ "$target" = "$src_path" ]; then
            return
        fi
        rm -f "$dst_path"
    elif [ -e "$dst_path" ]; then
        rm -rf "$dst_path"
    fi
    ln -s "$src_path" "$dst_path"
}

link_cargo_home() {
    local default_home="${HOME}/.cargo"
    if [ "$CARGO_HOME" = "$default_home" ]; then
        return
    fi
    link_cargo_component registry "$default_home" "$CARGO_HOME"
    link_cargo_component git "$default_home" "$CARGO_HOME"
    link_cargo_component bin "$default_home" "$CARGO_HOME"
    for file in .crates.toml .crates2.json credentials.toml config; do
        local src_file="$default_home/$file"
        local dst_file="$CARGO_HOME/$file"
        if [ -f "$src_file" ]; then
            if [ -L "$dst_file" ]; then
                local target
                target=$(readlink "$dst_file")
                if [ "$target" = "$src_file" ]; then
                    continue
                fi
                rm -f "$dst_file"
            elif [ -e "$dst_file" ]; then
                rm -f "$dst_file"
            fi
            ln -s "$src_file" "$dst_file"
        fi
    done
}

link_cargo_home

hard_need rustc
hard_need cargo

step "Tool versions"
rustc --version
cargo --version

run_cmd "cargo fmt" cargo fmt --all -- --check
run_cmd "cargo clippy" cargo clippy --workspace --all-targets --all-features --locked -- -D warnings
run_cmd "cargo test" cargo test --workspace --locked -- --nocapture
step "cargo package (greentic-demo)"
PACKAGE_LOG=$(mktemp 2>/dev/null || echo "/tmp/cargo-package.log")
if ! cargo package -p greentic-demo --allow-dirty --locked --offline 2>&1 | tee "$PACKAGE_LOG"; then
    echo "[fail] cargo package (offline)" >&2
    cat "$PACKAGE_LOG" >&2
    rm -f "$PACKAGE_LOG"
    exit 1
fi
rm -f "$PACKAGE_LOG"

echo ""
echo "local_check: all checks passed"
