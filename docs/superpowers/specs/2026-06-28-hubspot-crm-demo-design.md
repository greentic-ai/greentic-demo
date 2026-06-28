# HubSpot CRM Agentic-Worker Demo — Design

- **Date:** 2026-06-28
- **Status:** Approved (brainstorm) — pending implementation plan
- **Repo:** `greentic-demo` (branch `feat/agentic-worker-demo`)
- **Scope:** A runnable demo bundle that wires the published `greentic.hubspot`
  design extension into a `dw.agent` (Agentic Worker) node behind a WebChat flow —
  the HubSpot analogue of the existing `agentic-research-tavily-demo`.

## Goal

Let someone chat in WebChat with a "HubSpot CRM Assistant" — an LLM Agentic
Worker that manages a HubSpot CRM (contacts, deals, companies, tickets) using the
five `greentic.hubspot` tools. The demo must be **runnable** via the standard
greentic-demo flow (`gtc setup` → `gtc start`) once the operator supplies the
three run-time prerequisites (Redis, a DeepSeek key, a HubSpot Private App token).

## Model (matches the proven tavily demo)

The reference is `crates/agentic-research-tavily-demo/`, whose bundle is
confirmed working (`agentic-research-tavily-demo-bundle/logs/flow.log` shows
`node=assistant component=dw.agent status=Ok`). The HubSpot demo mirrors it
exactly, swapping Tavily for HubSpot. We follow greentic-demo's crate +
answers-driven packaging model — NOT a hand-authored loose bundle.

## Components

### New crate `crates/agentic-hubspot-crm-demo/`
- `Cargo.toml` — minimal metadata-wrapper crate (zero deps), added to the
  workspace `Cargo.toml` `members`. `src/lib.rs` exports `DEMO_NAME` +
  `bundle_dir()` per the repo pattern.
- `build-answer.json` — the source of truth consumed by the pack builder. Embeds:
  - **pack.yaml**: `pack_id: agentic-hubspot-crm-demo`, `version: 0.1.0`,
    `kind: application`, one flow (`on_message` → `flows/default.ygtc`), and one
    embedded agent:
    ```yaml
    agents:
      hubspot_assistant:
        agent_id: hubspot_assistant
        system_prompt: "<CRM assistant prompt: search-before-create,
          confirm-before-update/associate, report record id>"
        tools:
          - { extension_id: greentic.hubspot, tool_name: hubspot_contacts }
          - { extension_id: greentic.hubspot, tool_name: hubspot_deals }
          - { extension_id: greentic.hubspot, tool_name: hubspot_companies }
          - { extension_id: greentic.hubspot, tool_name: hubspot_tickets }
          - { extension_id: greentic.hubspot, tool_name: hubspot_associate }
        guardrails: []
        llm: { provider: deepseek, model: deepseek-chat, credential_ref: deepseek }
        limits: { max_iter: 8, timeout: 120 }
    ```
  - **flow `default.ygtc`** (`type: messaging`, `start: assistant`):
    `assistant` = `dw.agent` with `user_text: "{{in.input.text}}"`,
    `operation: hubspot_assistant`, routing → `send_reply` = `emit.response`
    with `text: "{{node.assistant.reply}}"`.
  - **secret_requirements**: `hubspot/access_token` (HubSpot Private App token)
    and `llm/deepseek` (DeepSeek key).
  - **credential questions** provider yaml: `deepseek` (LLM key) + `access_token`
    (HubSpot Private App token), both `secret: true, required: true`, with
    docs_url + placeholder.
- `assets/setup.yaml` — describes the run-time config (LLM provider/key + Redis
  via `GREENTIC_LLM_PROVIDER` / `GREENTIC_LLM_API_KEY` / `GREENTIC_AW_REDIS_URL`),
  mirroring the tavily crate.
- `README.md` — what it is, the WebChat → flow → dw.agent → reply diagram,
  prerequisites, and run steps.

### Demo answer artifacts (in `demos/`)
- `agentic-hubspot-crm-demo-create-answers.json` — cloned from the tavily
  create-answers, with `bundle_id`/`bundle_name`/`pack_id`/`rule_path` set to
  `agentic-hubspot-crm-demo[-bundle]` and the app-pack `reference` pointing at the
  HubSpot demo pack release URL. WebChat-GUI + WebChat providers and the
  `greentic.cap.bundle_assets.read.v1` capability are kept as-is.
- `agentic-hubspot-crm-demo-setup-answers.json` — cloned from tavily setup
  answers, ids swapped; supplies the per-tenant jwt signing key + access rules.

## Extension wiring

The agent references its tools by `extension_id: greentic.hubspot`. The runner
resolves and pulls `greentic.hubspot@1.2.0-research` from `store.greentic.cloud`
(already published) — no `.wasm` is bundled into the demo. The HubSpot token is
provided at run time and resolved by the runner as `secret://hubspot/access_token`.

## Build & run

- **Build:** `scripts/package_demos.sh` (needs `greentic-pack` + `gtc`) builds
  `demos/agentic-hubspot-crm-demo.gtpack` and composes the bundle. `ci/local_check.sh`
  (fmt + clippy + test + package_demos.sh) is the gate.
- **Run:** `gtc setup --answers <setup-answers> ./agentic-hubspot-crm-demo-bundle`
  then `gtc start ./agentic-hubspot-crm-demo-bundle`. Prerequisites supplied at
  run time: Redis (`GREENTIC_AW_REDIS_URL`), DeepSeek key
  (`GREENTIC_LLM_PROVIDER=deepseek` + `GREENTIC_LLM_API_KEY`), HubSpot token
  (`secret://hubspot/access_token`).

## Verification scope

We build the pack, validate the flow, and run `ci/local_check.sh`. A full live
chat run needs Redis + a DeepSeek key + a HubSpot token, which the operator
supplies — identical to the tavily demo's run requirements (that demo is
confirmed working via this model, so the path is proven).

## Out of scope (YAGNI)

Custom WebChat-GUI skin/branding, OAuth, multiple flows, seeded sample CRM data.
One flow, one agent, five tools.

## References
- Template: `crates/agentic-research-tavily-demo/` (+ its `demos/agentic-research-tavily-demo-*` answers and built bundle)
- Extension: `greentic-biz/component-hubspot-ext` → `greentic.hubspot@1.2.0-research` on store.greentic.cloud
- greentic-demo conventions: `CLAUDE.md` → "Adding a New Demo", `scripts/package_demos.sh`
