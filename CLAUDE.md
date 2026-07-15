# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

greentic-demo is a Rust workspace that collects independent Greentic demo crates. Each demo crate is a thin metadata wrapper exporting a name and bundle path; the real content is a `build-answer.json` (pack-build wizard answers) and an `assets/` directory (Adaptive Card JSON, i18n). The packaging pipeline (`scripts/package_demos.sh`) consumes these to produce `.gtpack` and `.gtbundle` artifacts under `demos/`. The repo also hosts standalone WASM component sub-crates under `crates/redbutton-demo/` that compile to `wasm32-wasip2` separately from the workspace.

## Build & Development Commands

```bash
# Build workspace (Rust 1.95.0 pinned via rust-toolchain.toml)
cargo build

# Format
cargo fmt --all

# Lint (pedantic + all warnings enabled via workspace lints)
cargo clippy --workspace --all-targets -- -D warnings

# Test
cargo test --workspace

# Test a single crate
cargo test -p quickstart-demo

# Local CI mirror (fmt + clippy + test + package demos)
ci/local_check.sh

# Package all demo packs + bundles (requires greentic-pack, gtc, jq; skips gracefully if missing)
scripts/package_demos.sh

# Package a single demo by name
scripts/package_demos.sh quickstart-demo
```

Note: `ci/local_check.sh` runs offline by default (`CARGO_NET_OFFLINE=1`). Set `CARGO_NET_OFFLINE=false` if you need to fetch dependencies. It also requires `python3` and `tar` (hard requirements).

### Building WASM Components

WASM component sub-crates (excluded from the workspace) require separate builds:

```bash
cd crates/redbutton-demo/component-http   # or component-random, component-betterstack-incident, greentic-http2play
cargo component build --release --target wasm32-wasip2
```

Each component directory has its own `Makefile` with targets: `build`, `wasm`, `check`, `lint`, `test`.

## Architecture

### Workspace Layout

```
crates/<demo-name>/          # Demo crates (workspace members)
  src/lib.rs                 # Exports DEMO_NAME const and bundle_dir()
  build-answer.json          # Pack-build wizard answers (consumed by package_demos.sh)
  assets/                    # Adaptive Card JSON (cards/) and locale files (i18n/)
  components/                # Component definitions (some crates only)
crates/redbutton-demo/       # Also a workspace member, plus 4 excluded WASM sub-crates
apps/                        # Standalone app packs (quickstart-app, pet-daycare-app)
demos/                       # Output: .gtpack archives + wizard answer .json files
scripts/                     # Packaging, publishing, and migration scripts
tools/                       # Utilities (i18n_extract_cards.py)
ci/                          # CI scripts (local_check.sh)
```

### Demo Crate Pattern

Demo crates have zero dependencies — they are metadata wrappers. The `src/lib.rs` is trivial:
```rust
pub const DEMO_NAME: &str = "quickstart-demo";
pub fn bundle_dir() -> &'static str { "bundle" }
```

All meaningful content lives in `build-answer.json` (wizard answers for `greentic-pack build`) and `assets/` (Adaptive Card JSON under `cards/`, i18n locale JSON under `i18n/`). The `bundle/` directory referenced by `bundle_dir()` is generated at packaging time, not committed.

### Current Demo Crates

18 workspace members (edition 2024, version `1.2.0-dev.0`):

| Crate | Domain |
|-------|--------|
| `quickstart-demo` | Minimal welcome card + menu |
| `quickstart-event-demo` | Event-driven quickstart |
| `incident-demo` | Incident management |
| `redbutton-demo` | Physical button + WASM components |
| `cards-demo` | Adaptive Card showcase |
| `cloud-deploy-demo` | Cloud deployment |
| `github-review-demo` | GitHub code review |
| `greentic-ai-demo` | Lead-capture multi-persona |
| `helpdesk-itsm-demo` | IT helpdesk portal |
| `hr-onboarding-demo` | HR onboarding |
| `sales-crm-demo` | Sales CRM |
| `supply-chain-demo` | Supply chain management |
| `weather-mcp-demo` | Weather MCP |
| `deep-research-demo` | Deep research |
| `pet-daycare-demo` | Pet daycare |
| `agentic-hubspot-crm-demo` | HubSpot CRM agentic worker |
| `agentic-research-tavily-agent` | Tavily research agent |
| `agentic-research-tavily-demo` | Tavily research demo |

`telco-x-demo` exists on disk but is NOT a workspace member (excluded from `Cargo.toml`).

### WASM Component Sub-Crates

Four component crates under `crates/redbutton-demo/` are excluded from the workspace because they target `wasm32-wasip2`:

- `component-http` — HTTP client operations
- `component-random` — Random value generation
- `component-betterstack-incident` — Better Stack incident integration
- `greentic-http2play` — HTTP to playback bridge

Each is a standalone Rust crate with `crate-type = ["cdylib", "rlib"]`, its own `Cargo.lock`, a `build.rs` for i18n bundling, and a `component.manifest.json` defining operations, capabilities, and schemas. They use `greentic-interfaces-guest` to implement the `greentic:component/component@0.6.0` world.

### Packaging & Publishing

- `scripts/package_demos.sh` is a two-stage pipeline: first builds `.gtpack` archives from each crate's `build-answer.json` via `greentic-pack` wizard, then composes `.gtbundle` SquashFS bundles from those packs via `gtc` wizard + `greentic-setup bundle build`. Requires `greentic-pack`, `gtc`, and `jq` (skips gracefully if missing). Accepts an optional demo name argument to package a single demo. Respects `GREENTIC_STORE_URL` (defaults to `https://store.greentic.cloud`) for `store://` extension resolution.
- CI publishes WASM components to GHCR via ORAS as OCI artifacts
- OCI publishing scripts: `publish_demo_packs_oci.sh`, `publish_demo_bundles_oci.sh`, `publish_demo_answers_oci.sh`, `publish_demo_artifacts_oci.sh`
- `demos/` contains `.gtpack` files and wizard answer `.json` files (create-answers, setup-answers)

## Adding a New Demo

1. Create a crate in `crates/<demo-name>/` with a minimal `Cargo.toml` (version/edition from workspace) and `src/lib.rs` (export `DEMO_NAME` + `bundle_dir()`)
2. Add `build-answer.json` with pack-build wizard answers and an `assets/` directory (cards + i18n)
3. Add the crate to `[workspace] members` in the root `Cargo.toml`
4. Run `ci/local_check.sh` to verify

## CI Pipeline

GitHub Actions (`ci.yml`) runs `ci/local_check.sh` which executes:
1. `python3 scripts/test_demo_json_remote_urls.py` (validate answer-file URLs)
2. `cargo fmt --all -- --check`
3. `cargo clippy --workspace --all-targets -- -D warnings`
4. `cargo test --workspace`
5. `scripts/package_demos.sh`

The publish workflow (`publish.yml`) builds WASM components, publishes packs and bundles to GHCR, and attaches `.gtpack`/`.gtbundle` files to GitHub Releases on tags.

## Workspace Lints

The workspace enables `clippy::all` and `clippy::pedantic` as warnings. All code must pass these checks.

## Git Conventions

Do NOT add Claude co-author attribution to commits or PRs.
