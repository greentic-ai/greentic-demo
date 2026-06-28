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
| `GREENTIC_SECRET_HUBSPOT_ACCESS_TOKEN` | HubSpot Private App token (`secret://hubspot/access_token`) — Private App mode only | `pat-...` |
| `GREENTIC_SECRET_HUBSPOT_AUTH_MODE` | Optional auth selector (`secret://hubspot/auth_mode`); `oauth` switches to broker-backed OAuth, anything else/unset = Private App | `oauth` |
| `GREENTIC_AW_REDIS_URL` | Redis the Agentic Worker uses for session state | `redis://127.0.0.1:6379` |

Start a local Redis first (for example `docker run -p 6379:6379 redis`). Create a
HubSpot Private App token at <https://developers.hubspot.com/docs/api/private-apps>
with CRM scopes for contacts, deals, companies, and tickets.

## OAuth mode (alternative)

The same demo can authenticate with **broker-backed OAuth** (auto-refreshed)
instead of a static Private App token. The HubSpot extension picks the mode from
`secret://hubspot/auth_mode`: set it to `oauth` and the agent's `hubspot_*` tools
fetch their token from the platform OAuth broker — the **broker**, not the demo,
refreshes it.

One-time prerequisite: register the HubSpot OAuth provider with the broker and
complete consent, following
[`component-hubspot-ext/docs/oauth-setup.md`](https://github.com/greentic-biz/component-hubspot-ext/blob/research/docs/oauth-setup.md).
Once the broker can mint a HubSpot token for your tenant, run the demo in OAuth
mode — note there is no `GREENTIC_SECRET_HUBSPOT_ACCESS_TOKEN`:

```bash
GREENTIC_LLM_PROVIDER=deepseek \
GREENTIC_LLM_API_KEY=sk-your-deepseek-key \
GREENTIC_SECRET_HUBSPOT_AUTH_MODE=oauth \
GREENTIC_AW_REDIS_URL=redis://127.0.0.1:6379 \
gtc start agentic-hubspot-crm-demo-bundle
```

This requires the OAuth broker host import (design-extension host) and the
extension's `auth_mode` support to be deployed in your runtime.

## How it works

- `flows/on_message.ygtc` is a `messaging` flow whose `start` node, `assistant`,
  is a `dw.agent`. Its `operation` (`hubspot_assistant`) selects the embedded
  agent declared under `agents:` in `pack.yaml`.
- The agent receives the user's message text as `user_text` and returns `reply`.
  It replies in English by default, switching language only if the user writes in
  another language.
- The `assistant` node has three exits, checked in order:
  1. **Confirmed create** — an Adaptive Card submit re-enters the flow with
     `response.action == create_contact_submit`, routing straight to `do_create`.
  2. **Create intent** — when the user asks to create a contact, the agent does
     **not** write; it emits the `[[CREATE_CONTACT]]` marker, and `show_create_card`
     sends an inline Adaptive Card form (first name, last name, email, phone,
     company) for the user to review and confirm.
  3. **Everything else** — a normal chat reply via `send_reply`.
- On the card's submit, `do_create` hands the confirmed fields to the agent,
  which calls `hubspot_contacts` (operation `create`) and reports the new record
  id and HubSpot URL. The card is the confirmation step: nothing is written until
  the user clicks **Create**.
- The agent's tools (`hubspot_contacts`, `hubspot_deals`, `hubspot_companies`,
  `hubspot_tickets`, `hubspot_associate`) come from the `greentic.hubspot`
  design extension, pulled from `store.greentic.cloud` at run time. No `.wasm` is
  bundled into the demo.

## Components

| Node | Kind | Purpose |
|------|------|---------|
| `assistant` | `dw.agent` (Agentic Worker) | HubSpot CRM assistant agent; branches on create-intent / card submit |
| `show_create_card` | `emit.response` (builtin) | Sends the inline Adaptive Card create/confirm form |
| `do_create` | `dw.agent` (Agentic Worker) | Creates the contact from the confirmed form fields |
| `send_reply` | `emit.response` (builtin) | Sends a normal agent reply back to chat |
| `send_create_reply` | `emit.response` (builtin) | Sends the create confirmation back to chat |

## Packaging

- Standard demo build entrypoint: `./scripts/package_demos.sh agentic-hubspot-crm-demo`.
- Pack build answers (the `pack_overlay` injecting the flow and `agents:` block) live in `build-answer.json`.
- Pack credential questions live in the `pack_overlay` `assets/setup.yaml` inside `build-answer.json`.
- Bundle-level run-time config questions live in `assets/setup.yaml`.
- Bundle creation answers live in `demos/agentic-hubspot-crm-demo-create-answers.json`.
- Bundle setup answers live in `demos/agentic-hubspot-crm-demo-setup-answers.json`.

## License

MIT
