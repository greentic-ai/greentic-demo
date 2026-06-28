#!/usr/bin/env bash
# install-greentic-demo-tools.sh — install the two research binaries the
# zero-env Tavily agentic-worker demo needs, WITHOUT building from source.
#
#   ./install-greentic-demo-tools.sh                 # installs into ~/.cargo/bin
#   PREFIX=/usr/local/bin ./install-greentic-demo-tools.sh
#
# Why two different install paths (this is the whole point of the script):
#
#   greentic-setup  has no git/private deps -> its research build IS on crates.io
#                   -> `cargo binstall greentic-setup@<ver>` resolves there.
#
#   greentic-start  pulls the agentic runtime (greentic-aw-runtime), which depends
#                   on PRIVATE / research-branch git repos (greentic-dw, ...). That
#                   makes it un-publishable to crates.io, and `cargo binstall --git`
#                   only reads a repo's DEFAULT branch (master), not research. So we
#                   fetch its prebuilt release tarball directly (curl + tar).
#
# Both crates publish identical GitHub-release assets:
#   <name>-v<version>-<target>.tgz   (binary inside <name>-v<version>-<target>/)
set -euo pipefail

SETUP_VER="${SETUP_VER:-1.2.0-research.0}"
START_VER="${START_VER:-1.2.0-research.2}"
PREFIX="${PREFIX:-$HOME/.cargo/bin}"
ORG="greenticai"

have() { command -v "$1" >/dev/null 2>&1; }

# ---- detect the rust target triple for this host ---------------------------
detect_target() {
  local os arch
  case "$(uname -s)" in
    Darwin)               os="apple-darwin" ;;
    Linux)                os="unknown-linux-gnu" ;;
    MINGW*|MSYS*|CYGWIN*) os="pc-windows-msvc" ;;
    *) echo "✗ unsupported OS: $(uname -s)" >&2; exit 1 ;;
  esac
  case "$(uname -m)" in
    x86_64|amd64)  arch="x86_64" ;;
    arm64|aarch64) arch="aarch64" ;;
    *) echo "✗ unsupported arch: $(uname -m)" >&2; exit 1 ;;
  esac
  printf '%s-%s' "$arch" "$os"
}
TARGET="$(detect_target)"
BIN_EXT=""; [[ "$TARGET" == *windows* ]] && BIN_EXT=".exe"

# ---- fetch a prebuilt release tarball and drop the binary into $PREFIX ------
install_via_curl() {                       # <repo> <version>
  local repo="$1" ver="$2"
  local dir="${repo}-v${ver}-${TARGET}"
  local asset="${dir}.tgz"
  local url="https://github.com/${ORG}/${repo}/releases/download/v${ver}/${asset}"
  echo "→ ${repo}: downloading ${asset}"
  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  if ! curl -fsSL "$url" -o "$tmp/$asset"; then
    echo "  ✗ no prebuilt asset for ${TARGET} (${url})" >&2
    return 1
  fi
  if curl -fsSL "${url}.sha256" -o "$tmp/${asset}.sha256" 2>/dev/null; then
    if ( cd "$tmp" && shasum -a 256 -c "${asset}.sha256" >/dev/null 2>&1 ); then
      echo "  ✓ checksum OK"
    else
      echo "  ✗ checksum mismatch — aborting" >&2; return 1
    fi
  fi
  tar xzf "$tmp/$asset" -C "$tmp"
  mkdir -p "$PREFIX"
  install -m 0755 "$tmp/${dir}/${repo}${BIN_EXT}" "$PREFIX/${repo}${BIN_EXT}"
}

echo "host target: ${TARGET}    install prefix: ${PREFIX}"
echo ""

# ---- greentic-setup: prefer crates.io binstall, fall back to curl+tar -------
if have cargo-binstall; then
  echo "→ greentic-setup: cargo binstall @${SETUP_VER} (crates.io)"
  cargo binstall -y --install-path "$PREFIX" "greentic-setup@${SETUP_VER}" \
    || { echo "  binstall failed, falling back to release tarball"; install_via_curl greentic-setup "$SETUP_VER"; }
else
  install_via_curl greentic-setup "$SETUP_VER"
fi

# ---- greentic-start: curl+tar only (not on crates.io; see header) ----------
install_via_curl greentic-start "$START_VER"

# ---- verify + PATH hint -----------------------------------------------------
echo ""
echo "✅ installed into ${PREFIX}:"
"$PREFIX/greentic-setup${BIN_EXT}" --version
"$PREFIX/greentic-start${BIN_EXT}" --version
case ":$PATH:" in
  *":$PREFIX:"*) ;;
  *) echo ""; echo "⚠  ${PREFIX} is not on your PATH — add it, e.g.:"; echo "     export PATH=\"${PREFIX}:\$PATH\"" ;;
esac
echo ""
echo "Next: configure + start a demo bundle, e.g.:"
echo "  greentic-setup ./agentic-research-tavily-demo-bundle"
echo "  greentic-start start --bundle ./agentic-research-tavily-demo-bundle --tenant demo --nats off --cloudflared off"
