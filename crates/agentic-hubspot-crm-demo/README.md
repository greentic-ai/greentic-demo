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
