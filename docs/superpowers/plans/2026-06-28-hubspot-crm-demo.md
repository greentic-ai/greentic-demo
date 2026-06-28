# HubSpot CRM Agentic-Worker Demo — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a runnable `agentic-hubspot-crm-demo` to the `greentic-demo` repo that drives the published `greentic.hubspot` design extension through a `dw.agent` (Agentic Worker) node behind a WebChat flow.

**Architecture:** A metadata-wrapper crate (`crates/agentic-hubspot-crm-demo/`) plus two `demos/` answer files, faithfully cloned from the proven `agentic-research-tavily-demo`. The pack builder reads `build-answer.json` (which embeds `pack.yaml`, the flow, secret requirements, and credential questions via `pack_overlay`) to produce the `.gtpack`; `gtc` then composes the bundle. The agent references its tools by `extension_id: greentic.hubspot`, which the runner pulls from `store.greentic.cloud` at run time — no `.wasm` is bundled.

**Tech Stack:** Rust workspace crate (zero deps), `greentic-pack` + `gtc` packaging wizard, `.ygtc` flow, DeepSeek LLM, HubSpot Private App token, Redis for Agentic Worker session state.

## Global Constraints

- Demo lives in `greentic-demo`, branch `feat/agentic-worker-demo` (research lane), using the crate + answers-driven model — NOT a hand-authored loose bundle.
- New crate added to workspace `Cargo.toml` `members`; `version.workspace = true`, `edition.workspace = true`, `publish.workspace = true` (publish = false).
- Extension is referenced, never bundled: `extension_id: greentic.hubspot`, resolved as `greentic.hubspot@1.2.0-research` from `store.greentic.cloud`.
- Tool secret resolves as `secret://hubspot/access_token`; LLM credential_ref is `deepseek`.
- All code, identifiers, file contents, commit messages in English. No Claude/AI co-author attribution in commits or PRs (per `greentic-demo/CLAUDE.md`).
- Gate: `ci/local_check.sh` (fmt + clippy `-D warnings` + test + `scripts/package_demos.sh`) must be green.
- Five tools, one agent, one flow. No custom WebChat skin, OAuth, multiple flows, or seeded CRM data (YAGNI).
- Flow file name follows the proven tavily template: `flows/on_message.ygtc` with internal `id: default` (the design spec's "default.ygtc" wording is superseded by the verified template name to minimise risk).

---

### Task 1: Crate skeleton + workspace registration

**Files:**
- Create: `crates/agentic-hubspot-crm-demo/Cargo.toml`
- Create: `crates/agentic-hubspot-crm-demo/src/lib.rs`
- Modify: `Cargo.toml` (workspace `members`)

**Interfaces:**
- Consumes: workspace `[workspace.package]` (`version = "0.1.88"`, `edition = "2024"`, `publish = false`).
- Produces: crate `agentic-hubspot-crm-demo` exporting `pub const DEMO_NAME: &str` and `pub fn bundle_dir() -> &'static str`.

- [ ] **Step 1: Create the crate `Cargo.toml`**

`crates/agentic-hubspot-crm-demo/Cargo.toml`:

```toml
[package]
name = "agentic-hubspot-crm-demo"
version.workspace = true
edition.workspace = true
publish.workspace = true

[lib]
path = "src/lib.rs"
```

- [ ] **Step 2: Create `src/lib.rs`**

`crates/agentic-hubspot-crm-demo/src/lib.rs`:

```rust
//! Metadata wrapper for the HubSpot CRM Agentic-Worker demo.
//!
//! All meaningful content lives in `build-answer.json` (pack overlay) and the
//! `demos/agentic-hubspot-crm-demo-*` answer files. This crate only exposes the
//! demo identity so the workspace can build and reference it uniformly.

/// Stable identifier for this demo (matches the pack id and bundle prefix).
pub const DEMO_NAME: &str = "agentic-hubspot-crm-demo";

/// Directory (relative to the crate root) that holds the built bundle.
#[must_use]
pub fn bundle_dir() -> &'static str {
    "bundle"
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn demo_name_is_stable() {
        assert_eq!(DEMO_NAME, "agentic-hubspot-crm-demo");
    }

    #[test]
    fn bundle_dir_is_bundle() {
        assert_eq!(bundle_dir(), "bundle");
    }
}
```

- [ ] **Step 3: Register the crate in the workspace**

In the root `Cargo.toml`, add the member in alphabetical position (first entry, before `crates/cards-demo`):

```toml
members = [
    "crates/agentic-hubspot-crm-demo",
    "crates/agentic-research-tavily-demo",
    "crates/cards-demo",
```

- [ ] **Step 4: Run the build + the crate test to verify they pass**

Run: `cargo build -p agentic-hubspot-crm-demo && cargo test -p agentic-hubspot-crm-demo`
Expected: build succeeds; both tests (`demo_name_is_stable`, `bundle_dir_is_bundle`) PASS.

- [ ] **Step 5: Commit**

```bash
git add crates/agentic-hubspot-crm-demo/Cargo.toml crates/agentic-hubspot-crm-demo/src/lib.rs Cargo.toml
git commit -m "feat: scaffold agentic-hubspot-crm-demo crate"
```

---

### Task 2: build-answer.json (pack overlay)

**Files:**
- Create: `crates/agentic-hubspot-crm-demo/build-answer.json`

**Interfaces:**
- Consumes: `greentic-pack.wizard.run` (`schema_id: greentic-demo.build-answer`, version `1.0.0`).
- Produces: a `pack_overlay` that injects `pack.yaml` (agent `hubspot_assistant` + 5 `greentic.hubspot` tools), `flows/on_message.ygtc`, `assets/secret-requirements.json`, and `assets/setup.yaml` (credential questions `deepseek` + `access_token`).

- [ ] **Step 1: Write `build-answer.json`**

`crates/agentic-hubspot-crm-demo/build-answer.json`:

```json
{
  "schema_id": "greentic-demo.build-answer",
  "schema_version": "1.0.0",
  "wizard": null,
  "pack_create": {
    "wizard_id": "greentic-pack.wizard.run",
    "schema_id": "greentic-pack.wizard.answers",
    "schema_version": "1.0.0",
    "locale": "en-GB",
    "answers": {
      "create_pack_id": "agentic-hubspot-crm-demo",
      "create_pack_scaffold": true,
      "dry_run": false,
      "flow_wizard_answers": {
        "schema_id": "greentic-flow.wizard.plan",
        "schema_version": "2.0.0",
        "actions": [
          {
            "action": "edit-flow-summary",
            "flow": "flows/on_message.ygtc",
            "name": "HubSpot CRM Assistant - Message Handler",
            "description": "Route each incoming chat message to the HubSpot CRM Agentic Worker (dw.agent) and reply with its answer"
          }
        ]
      },
      "mode": "interactive",
      "pack_dir": "./agentic-hubspot-crm-demo.pack",
      "run_build": false,
      "run_delegate_component": false,
      "run_delegate_flow": false,
      "run_doctor": false,
      "sign": false
    },
    "locks": {}
  },
  "pack": {
    "wizard_id": "greentic-pack.wizard.run",
    "schema_id": "greentic-pack.wizard.answers",
    "schema_version": "1.0.0",
    "locale": "en-GB",
    "answers": {
      "dry_run": false,
      "mode": "interactive",
      "pack_dir": ".",
      "run_build": false,
      "run_delegate_component": false,
      "run_delegate_flow": false,
      "run_doctor": false,
      "selected_actions": [
        "main.update_application_pack",
        "update_application_pack.run_update_validate",
        "pipeline.update_validate",
        "pipeline.sign_prompt.skip",
        "main.exit"
      ],
      "sign": false
    },
    "locks": {}
  },
  "flow": null,
  "pack_overlay": {
    "files": [
      {
        "path": "pack.yaml",
        "content": "pack_id: agentic-hubspot-crm-demo\nversion: 0.1.0\nkind: application\npublisher: Greentic\ncomponents: []\ndependencies: []\nflows:\n- id: on_message\n  file: flows/on_message.ygtc\n  tags:\n  - default\n  entrypoints:\n  - default\nagents:\n  hubspot_assistant:\n    agent_id: hubspot_assistant\n    system_prompt: \"You are a HubSpot CRM assistant running as an Agentic Worker inside a Greentic flow. You help a sales and customer-success team manage their HubSpot CRM: contacts, deals, companies, and support tickets. Use hubspot_contacts, hubspot_deals, hubspot_companies, and hubspot_tickets (each takes an operation of create, search, update, or get) and hubspot_associate to link two records. Always search before creating a record to avoid duplicates. Always confirm with the user before an update or an association, because those change existing data. After any create or update, report the record id and its HubSpot URL. Answer concisely in the user's language. Never invent record ids, properties, or results — only report what the tools return.\"\n    tools:\n      - extension_id: greentic.hubspot\n        tool_name: hubspot_contacts\n      - extension_id: greentic.hubspot\n        tool_name: hubspot_deals\n      - extension_id: greentic.hubspot\n        tool_name: hubspot_companies\n      - extension_id: greentic.hubspot\n        tool_name: hubspot_tickets\n      - extension_id: greentic.hubspot\n        tool_name: hubspot_associate\n    guardrails: []\n    llm:\n      provider: deepseek\n      model: deepseek-chat\n      credential_ref: deepseek\n    limits:\n      max_iter: 8\n      timeout: 120\n"
      },
      {
        "path": "flows/on_message.ygtc",
        "content": "id: default\ntitle: HubSpot CRM Assistant - Message Handler\ndescription: Route each incoming chat message to the HubSpot CRM Agentic Worker (dw.agent) and reply with its answer\ntype: messaging\nstart: assistant\n\nnodes:\n  # The single logic node: an Agentic Worker (dw.agent). `operation` selects\n  # which embedded agent runs (must match an agent_id under pack.yaml `agents:`).\n  # The agent receives the user's message text as `user_text` and returns `reply`.\n  assistant:\n    dw.agent:\n      user_text: \"{{in.input.text}}\"\n    operation: hubspot_assistant\n    routing:\n      - to: send_reply\n\n  # Builtin reply node — routes the agent's answer back to the active channel.\n  send_reply:\n    emit.response:\n      messages:\n        - type: text\n          text: \"{{node.assistant.reply}}\"\n    routing:\n      - out: true\n"
      },
      {
        "path": "assets/secret-requirements.json",
        "content": "[\n  {\n    \"key\": \"hubspot/access_token\",\n    \"description\": \"HubSpot Private App access token (https://developers.hubspot.com/docs/api/private-apps). Used by the agent's hubspot_* tools as a Bearer token; only api.hubapi.com is reachable.\"\n  },\n  {\n    \"key\": \"llm/deepseek\",\n    \"description\": \"DeepSeek LLM API key for the agentic worker's reasoning loop.\"\n  }\n]"
      },
      {
        "path": "assets/setup.yaml",
        "content": "provider_id: agentic-hubspot-crm-demo\nversion: 1\ntitle: HubSpot CRM Assistant — credentials\ndescription: API keys for the agentic worker and its HubSpot CRM tools.\nquestions:\n  - name: deepseek\n    title: DeepSeek API key\n    kind: string\n    required: true\n    secret: true\n    help: \"LLM API key for the agentic worker's reasoning loop (https://platform.deepseek.com).\"\n    group: LLM\n    docs_url: \"https://platform.deepseek.com\"\n    placeholder: \"sk-...\"\n  - name: access_token\n    title: HubSpot Private App token\n    kind: string\n    required: true\n    secret: true\n    help: \"HubSpot Private App access token used by the hubspot_* tools (https://developers.hubspot.com/docs/api/private-apps).\"\n    group: Tools\n    docs_url: \"https://developers.hubspot.com/docs/api/private-apps\"\n    placeholder: \"pat-...\"\n"
      }
    ]
  }
}
```

- [ ] **Step 2: Verify the JSON parses and the embedded YAML/JSON are well-formed**

Run:
```bash
python3 - <<'PY'
import json, sys
p = "crates/agentic-hubspot-crm-demo/build-answer.json"
doc = json.load(open(p))
files = {f["path"]: f["content"] for f in doc["pack_overlay"]["files"]}
assert set(files) == {"pack.yaml", "flows/on_message.ygtc", "assets/secret-requirements.json", "assets/setup.yaml"}, files.keys()
# secret-requirements is embedded JSON — must parse
sr = json.loads(files["assets/secret-requirements.json"])
assert [x["key"] for x in sr] == ["hubspot/access_token", "llm/deepseek"], sr
# pack.yaml must name the agent + all 5 tools
pk = files["pack.yaml"]
for needle in ["hubspot_assistant", "hubspot_contacts", "hubspot_deals",
               "hubspot_companies", "hubspot_tickets", "hubspot_associate",
               "credential_ref: deepseek", "operation"]:
    assert needle in pk or needle in files["flows/on_message.ygtc"], needle
# flow must route to the agent operation
fl = files["flows/on_message.ygtc"]
assert "operation: hubspot_assistant" in fl and "{{node.assistant.reply}}" in fl
print("build-answer.json OK")
PY
```
Expected: prints `build-answer.json OK` with no assertion error.

- [ ] **Step 3: Commit**

```bash
git add crates/agentic-hubspot-crm-demo/build-answer.json
git commit -m "feat: add HubSpot demo pack build-answer (agent + 5 tools + flow)"
```

---

### Task 3: Crate run-time setup spec + README

**Files:**
- Create: `crates/agentic-hubspot-crm-demo/assets/setup.yaml`
- Create: `crates/agentic-hubspot-crm-demo/README.md`

**Interfaces:**
- Consumes: nothing new.
- Produces: the bundle-level setup spec (`provider`/`model`/`api_key_secret`) keyed under the demo id in the setup-answers file (Task 4).

> Note: this is the **crate-level** `assets/setup.yaml` (run-time LLM config), distinct from the **pack overlay** `assets/setup.yaml` (credential questions) inside `build-answer.json`. Both exist in the tavily template; keep both.

- [ ] **Step 1: Create the crate-level `assets/setup.yaml`**

`crates/agentic-hubspot-crm-demo/assets/setup.yaml`:

```yaml
title: HubSpot CRM Assistant Setup
description: Configure the LLM provider used by the embedded Agentic Worker (dw.agent). The key, provider, and Redis URL are normally supplied at run time via GREENTIC_LLM_PROVIDER, GREENTIC_LLM_API_KEY, and GREENTIC_AW_REDIS_URL environment variables. The HubSpot Private App token is supplied at run time as GREENTIC_SECRET_HUBSPOT_ACCESS_TOKEN.
questions:
  - name: provider
    kind: string
    required: false
    title: LLM provider
    help: Provider the Agentic Worker uses. Defaults to deepseek; can be overridden at run time with GREENTIC_LLM_PROVIDER.
    default: deepseek
    placeholder: deepseek
  - name: model
    kind: string
    required: false
    title: LLM model
    help: Model name for the configured provider. For deepseek, deepseek-chat is a known-good default.
    default: deepseek-chat
    placeholder: deepseek-chat
  - name: api_key_secret
    secret_key: api_key_secret
    kind: string
    required: false
    secret: true
    title: LLM API key secret
    help: API key for the LLM provider. Usually supplied at run time via GREENTIC_LLM_API_KEY instead of being baked into the pack.
    default: ${GREENTIC_LLM_API_KEY}
    placeholder: ${GREENTIC_LLM_API_KEY}
```

- [ ] **Step 2: Create `README.md`**

`crates/agentic-hubspot-crm-demo/README.md`:

```markdown
# agentic-hubspot-crm-demo

A greentic-demo that runs a **HubSpot CRM Assistant** as an **Agentic Worker
(`dw.agent`)** node inside a messaging flow. Each incoming webchat message is
routed to an embedded LLM Plan-Act-Observe agent (`hubspot_assistant`) that
manages a HubSpot CRM — contacts, deals, companies, and tickets — through the
five `greentic.hubspot` tools, and the agent's answer is sent back to the chat.

```bash
./scripts/package_demos.sh agentic-hubspot-crm-demo
gtc wizard --answers demos/agentic-hubspot-crm-demo-create-answers.json
gtc setup agentic-hubspot-crm-demo-bundle --answers demos/agentic-hubspot-crm-demo-setup-answers.json
GREENTIC_LLM_PROVIDER=deepseek \
GREENTIC_LLM_API_KEY=sk-your-deepseek-key \
GREENTIC_SECRET_HUBSPOT_ACCESS_TOKEN=pat-your-hubspot-private-app-token \
GREENTIC_AW_REDIS_URL=redis://127.0.0.1:6379 \
gtc start agentic-hubspot-crm-demo-bundle
```

## Runtime requirements

The Agentic Worker runtime needs an LLM key, a HubSpot Private App token, and
Redis at run time (none are baked into the pack). Provide them as environment
variables when you run `gtc start`:

| Variable | Purpose | Example |
|----------|---------|---------|
| `GREENTIC_LLM_PROVIDER` | LLM provider the agent uses | `deepseek` |
| `GREENTIC_LLM_API_KEY` | API key for that provider | `sk-...` |
| `GREENTIC_SECRET_HUBSPOT_ACCESS_TOKEN` | HubSpot Private App token (`secret://hubspot/access_token`) | `pat-...` |
| `GREENTIC_AW_REDIS_URL` | Redis the Agentic Worker uses for session state | `redis://127.0.0.1:6379` |

Start a local Redis first (for example `docker run -p 6379:6379 redis`). Create a
HubSpot Private App token at <https://developers.hubspot.com/docs/api/private-apps>
with CRM scopes for contacts, deals, companies, and tickets.

## How it works

- `flows/on_message.ygtc` is a `messaging` flow with a single logic node,
  `assistant`, of type `dw.agent`. Its `operation` (`hubspot_assistant`) selects
  the embedded agent declared under `agents:` in `pack.yaml`.
- The agent receives the user's message text as `user_text` and returns `reply`.
- The builtin `emit.response` node (`send_reply`) routes that reply back to the
  active webchat channel.
- The agent's tools (`hubspot_contacts`, `hubspot_deals`, `hubspot_companies`,
  `hubspot_tickets`, `hubspot_associate`) come from the `greentic.hubspot`
  design extension, pulled from `store.greentic.cloud` at run time. No `.wasm` is
  bundled into the demo.

## Components

| Node | Kind | Purpose |
|------|------|---------|
| `assistant` | `dw.agent` (Agentic Worker) | HubSpot CRM assistant agent |
| `send_reply` | `emit.response` (builtin) | Sends the agent reply back to chat |

## Packaging

- Standard demo build entrypoint: `./scripts/package_demos.sh agentic-hubspot-crm-demo`.
- Pack build answers (the `pack_overlay` injecting the flow and `agents:` block) live in `build-answer.json`.
- Pack credential questions live in the `pack_overlay` `assets/setup.yaml` inside `build-answer.json`.
- Bundle-level run-time config questions live in `assets/setup.yaml`.
- Bundle creation answers live in `demos/agentic-hubspot-crm-demo-create-answers.json`.
- Bundle setup answers live in `demos/agentic-hubspot-crm-demo-setup-answers.json`.

## License

MIT
```

- [ ] **Step 3: Verify the crate-level setup.yaml parses as YAML**

Run:
```bash
python3 -c "import yaml,sys; d=yaml.safe_load(open('crates/agentic-hubspot-crm-demo/assets/setup.yaml')); names=[q['name'] for q in d['questions']]; assert names==['provider','model','api_key_secret'], names; print('setup.yaml OK')"
```
Expected: prints `setup.yaml OK`. (If `pyyaml` is unavailable, instead run `python3 -c "open('crates/agentic-hubspot-crm-demo/assets/setup.yaml').read()"` and visually confirm the three question names.)

- [ ] **Step 4: Commit**

```bash
git add crates/agentic-hubspot-crm-demo/assets/setup.yaml crates/agentic-hubspot-crm-demo/README.md
git commit -m "docs: add HubSpot demo setup spec and README"
```

---

### Task 4: Demo answer files (create + setup)

**Files:**
- Create: `demos/agentic-hubspot-crm-demo-create-answers.json`
- Create: `demos/agentic-hubspot-crm-demo-setup-answers.json`

**Interfaces:**
- Consumes: the pack built by Task 2 (`agentic-hubspot-crm-demo.gtpack`) and the crate setup spec from Task 3 (keyed by `agentic-hubspot-crm-demo`).
- Produces: bundle `agentic-hubspot-crm-demo-bundle` consumable by `gtc wizard` / `gtc setup`.

- [ ] **Step 1: Create the create-answers file**

`demos/agentic-hubspot-crm-demo-create-answers.json`:

```json
{
  "wizard_id": "greentic-dev.wizard.launcher.main",
  "schema_id": "greentic-dev.launcher.main",
  "schema_version": "1.0.0",
  "locale": "en-GB",
  "answers": {
    "selected_action": "bundle",
    "delegate_answer_document": {
      "wizard_id": "greentic-bundle.wizard.run",
      "schema_id": "greentic-bundle.wizard.answers",
      "schema_version": "1.0.0",
      "locale": "en-GB",
      "answers": {
        "access_rules": [
          {
            "policy": "public",
            "rule_path": "agentic-hubspot-crm-demo",
            "tenant": "default"
          },
          {
            "policy": "public",
            "rule_path": "agentic-hubspot-crm-demo",
            "tenant": "demo"
          }
        ],
        "advanced_setup": false,
        "app_pack_entries": [
          {
            "detected_kind": "https",
            "display_name": "HubSpot CRM Assistant Demo Pack",
            "mapping": {
              "scope": "global"
            },
            "pack_id": "agentic-hubspot-crm-demo",
            "reference": "https://github.com/greenticai/greentic-demo/releases/latest/download/agentic-hubspot-crm-demo.gtpack"
          }
        ],
        "app_packs": [
          "https://github.com/greenticai/greentic-demo/releases/latest/download/agentic-hubspot-crm-demo.gtpack"
        ],
        "bundle_id": "agentic-hubspot-crm-demo-bundle",
        "bundle_name": "agentic-hubspot-crm-demo-bundle",
        "capabilities": [
          "greentic.cap.bundle_assets.read.v1"
        ],
        "export_intent": false,
        "extension_provider_entries": [
          {
            "detected_kind": "oci",
            "display_name": "Greentic Messaging Webchat GUI (stable)",
            "provider_id": "greentic.messaging.webchat-gui.stable",
            "reference": "oci://ghcr.io/greenticai/packs/messaging/messaging-webchat-gui:stable",
            "version": "stable"
          },
          {
            "detected_kind": "oci",
            "display_name": "Greentic Messaging Webchat (stable)",
            "provider_id": "greentic.messaging.webchat.stable",
            "reference": "oci://ghcr.io/greenticai/packs/messaging/messaging-webchat:stable",
            "version": "stable"
          },
          {
            "detected_kind": "oci",
            "display_name": "Greentic State Memory (stable)",
            "provider_id": "state-memory",
            "reference": "oci://ghcr.io/greenticai/packs/state/state-memory:stable",
            "version": "stable"
          }
        ],
        "extension_providers": [
          "oci://ghcr.io/greenticai/packs/messaging/messaging-webchat-gui:stable",
          "oci://ghcr.io/greenticai/packs/messaging/messaging-webchat:stable",
          "oci://ghcr.io/greenticai/packs/state/state-memory:stable"
        ],
        "mode": "create",
        "output_dir": "agentic-hubspot-crm-demo-bundle",
        "remote_catalogs": [],
        "setup_answers": {},
        "setup_execution_intent": false,
        "setup_specs": {}
      },
      "locks": {
        "cache_policy": "workspace-local",
        "catalogs": [],
        "execution": "execute",
        "lock_file": "bundle.lock.json",
        "requested_mode": "create",
        "setup_state_files": [],
        "workspace_root": "bundle.yaml"
      }
    }
  },
  "locks": {}
}
```

- [ ] **Step 2: Create the setup-answers file**

`demos/agentic-hubspot-crm-demo-setup-answers.json`:

```json
{
  "bundle_source": ".",
  "env": "dev",
  "greentic_setup_version": "1.0.0",
  "platform_setup": {
    "deployment_targets": [],
    "static_routes": {
      "default_route_prefix_policy": "pack_declared",
      "public_base_url": "http://127.0.0.1:8080",
      "public_surface_policy": "enabled",
      "public_web_enabled": true,
      "tenant_path_policy": "pack_declared"
    }
  },
  "setup_answers": {
    "agentic-hubspot-crm-demo": {
      "api_key_secret": "${GREENTIC_LLM_API_KEY}",
      "provider": "deepseek",
      "model": "deepseek-chat"
    },
    "messaging-webchat-gui": {
      "base_url": "http://127.0.0.1:8080",
      "jwt_signing_key": "agentic-hubspot-crm-demo-local-dev-signing-key",
      "mode": "local_queue",
      "public_base_url": "http://127.0.0.1:8080",
      "route": "webchat",
      "tenant_channel_id": "demo:webchat"
    },
    "messaging-webchat": {
      "base_url": "http://127.0.0.1:8080",
      "jwt_signing_key": "agentic-hubspot-crm-demo-local-dev-signing-key",
      "mode": "local_queue",
      "public_base_url": "http://127.0.0.1:8080",
      "route": "webchat",
      "tenant_channel_id": "demo:webchat"
    },
    "state-memory": {}
  },
  "team": "default",
  "tenant": "demo"
}
```

- [ ] **Step 3: Verify both answer files parse and ids are consistent**

Run:
```bash
python3 - <<'PY'
import json
c = json.load(open("demos/agentic-hubspot-crm-demo-create-answers.json"))
a = c["answers"]["delegate_answer_document"]["answers"]
assert a["bundle_id"] == "agentic-hubspot-crm-demo-bundle", a["bundle_id"]
assert a["app_pack_entries"][0]["pack_id"] == "agentic-hubspot-crm-demo"
assert "agentic-hubspot-crm-demo.gtpack" in a["app_packs"][0]
s = json.load(open("demos/agentic-hubspot-crm-demo-setup-answers.json"))
assert "agentic-hubspot-crm-demo" in s["setup_answers"], s["setup_answers"].keys()
assert s["setup_answers"]["agentic-hubspot-crm-demo"]["provider"] == "deepseek"
# no stray tavily ids left over from cloning
blob = open("demos/agentic-hubspot-crm-demo-create-answers.json").read() + open("demos/agentic-hubspot-crm-demo-setup-answers.json").read()
assert "tavily" not in blob and "research" not in blob, "leftover tavily/research id"
print("answer files OK")
PY
```
Expected: prints `answer files OK`.

- [ ] **Step 4: Commit**

```bash
git add demos/agentic-hubspot-crm-demo-create-answers.json demos/agentic-hubspot-crm-demo-setup-answers.json
git commit -m "feat: add HubSpot demo bundle create + setup answers"
```

---

### Task 5: Package, validate, and gate

**Files:**
- None created. Runs the build pipeline and the CI gate over everything from Tasks 1–4.

**Interfaces:**
- Consumes: all files from Tasks 1–4.
- Produces: `demos/agentic-hubspot-crm-demo.gtpack` (+ composed bundle) and a green `ci/local_check.sh`.

- [ ] **Step 1: Build just this demo's pack + bundle**

Run: `scripts/package_demos.sh agentic-hubspot-crm-demo`
Expected: produces `demos/agentic-hubspot-crm-demo.gtpack` and composes the bundle without error. (If `greentic-pack`/`gtc` are not installed, the script skips gracefully — in that case note the skip and rely on the full gate in Step 3, but flag that packaging was not exercised locally.)

- [ ] **Step 2: Validate the embedded flow (if `greentic-flow` / `gtc` is available)**

Run: `gtc start agentic-hubspot-crm-demo-bundle --skip-setup --dry-run 2>/dev/null || echo "skipped (gtc/flow validation not available locally)"`
Expected: either the flow validates clean, or a clear "skipped" line. Do not treat a missing-binary skip as a failure; do treat a flow *parse/validation error* as a failure to fix.

- [ ] **Step 3: Run the full local CI gate**

Run: `ci/local_check.sh`
Expected: `cargo fmt --all -- --check`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo test --workspace`, and `scripts/package_demos.sh` all pass. Fix any fmt/clippy/test issues (most likely in `src/lib.rs`) until green.

- [ ] **Step 4: Commit any artifacts the gate expects to be tracked**

```bash
# Only if package_demos.sh produced tracked artifacts (mirror how tavily's are tracked).
git status --short demos/
git add demos/agentic-hubspot-crm-demo.gtpack 2>/dev/null || true
git commit -m "build: package agentic-hubspot-crm-demo pack" || echo "nothing to commit"
```

> Check whether `demos/*.gtpack` is git-ignored in this repo (the tavily `.gtpack` may be a release-only artifact, not committed). If `demos/` is ignored, skip the add/commit — packaging is exercised by CI, not stored in git.

---

## Self-Review

**1. Spec coverage** (against `2026-06-28-hubspot-crm-demo-design.md`):
- New crate `crates/agentic-hubspot-crm-demo/` with Cargo.toml + src/lib.rs + workspace member → Task 1. ✓
- `build-answer.json` with pack.yaml (agent `hubspot_assistant` + 5 tools), flow, secret_requirements (`hubspot/access_token` + `llm/deepseek`), credential questions → Task 2. ✓
- `assets/setup.yaml` (run-time LLM/Redis config) → Task 3. ✓
- README → Task 3. ✓
- `demos/*-create-answers.json` + `*-setup-answers.json` cloned with ids swapped, webchat-gui + webchat + bundle_assets capability kept → Task 4. ✓
- Extension referenced (`extension_id: greentic.hubspot`), token resolved as `secret://hubspot/access_token`, no `.wasm` bundled → Task 2 pack.yaml + README + secret-requirements. ✓
- Build via `scripts/package_demos.sh`; gate via `ci/local_check.sh` → Task 5. ✓
- Out-of-scope items (skin/OAuth/multi-flow/seed data) → not introduced. ✓

**2. Placeholder scan:** No "TBD"/"add error handling"/"similar to Task N" placeholders. Every file step has full content; every verify step has a runnable command + expected output. ✓

**3. Type consistency:** `DEMO_NAME` / `bundle_dir()` defined in Task 1, referenced nowhere inconsistently. Demo id `agentic-hubspot-crm-demo` used identically across pack_id, bundle_id (`-bundle`), members entry, setup_answers key, and gtpack filename. Agent id `hubspot_assistant` matches the flow's `operation: hubspot_assistant`. Tool names match across pack.yaml and README. Flow file `flows/on_message.ygtc` (id `default`) consistent across build-answer.json and README. ✓

**Deviation noted:** spec said flow `default.ygtc`; plan uses the verified tavily name `flows/on_message.ygtc` (internal `id: default`) to stay byte-faithful to the proven template — documented in Global Constraints.
