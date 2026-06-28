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

## Connection method (in setup)

When you run `gtc setup`, the HubSpot credentials form asks **how the tools
authenticate** with a *Connection method* picker:

- **Private App token** (default) — paste a HubSpot Private App token; the field
  appears only for this choice. Simplest, works immediately.
- **OAuth** — connect a real HubSpot OAuth app right from the setup form. Choosing
  it reveals *Client ID*, *Client Secret*, and a live **Connect HubSpot** button.
  On success the tools use auto-refreshed OAuth tokens (no static token).

The connection runs **inside `gtc setup`** — there is no separate broker process.

## OAuth mode (connect from setup)

The same demo can authenticate with **OAuth** (auto-refreshed) instead of a static
Private App token. `gtc setup` itself runs the OAuth authorization-code flow and
stores a refresh token; at run time the HubSpot extension refreshes the access
token directly against HubSpot (no broker).

One-time prerequisite — create a **HubSpot OAuth app**
(<https://developers.hubspot.com/docs/api/oauth-quickstart-guide>):

1. In the app's **Auth** tab, register the redirect URL
   `http://localhost:8765/api/oauth/callback` (must match exactly).
2. Add CRM scopes: `oauth`, `crm.objects.contacts.read/write`,
   `crm.objects.companies.read/write`, `crm.objects.deals.read/write`, `tickets`.
3. Copy the **Client ID** and **Client Secret**.

Then run setup on the **fixed port** the redirect was registered with, choose
*OAuth*, paste the Client ID/Secret, and click **Connect HubSpot**:

```bash
gtc setup --port 8765 agentic-hubspot-crm-demo-bundle
```

A popup opens the real HubSpot consent screen; after you authorize, the form shows
**Connected ✓** and the demo stores `secret://hubspot/auth_mode=oauth` plus the
refresh token and client credentials. No `GREENTIC_SECRET_HUBSPOT_ACCESS_TOKEN` is
needed — start the demo as usual and the `hubspot_*` tools use auto-refreshed
OAuth tokens.

This needs a `gtc` whose `greentic-setup` includes the embedded OAuth client and
whose `greentic.hubspot` extension includes brokerless refresh. On an older `gtc`
the Connect button shows as a text field — leave it blank and use Private App
token instead.

## How it works

- `flows/on_message.ygtc` is a `messaging` flow with a single logic node,
  `assistant`, of type `dw.agent`. Its `operation` (`hubspot_assistant`) selects
  the embedded agent declared under `agents:` in `pack.yaml`.
- The agent receives the user's message text as `user_text` and returns `reply`.
  It always replies in English (every reply, including greetings), regardless of
  the language the user writes in.
- **Creating a record is confirmed in chat before it is written.** When the user
  asks to create a contact, the agent does **not** write immediately: it first
  replies with a summary of the fields it understood (first name, last name,
  email, phone, company — `not provided` for any missing) and asks the user to
  reply `yes` to create or correct a field. Only after the user confirms does it
  call `hubspot_contacts` (operation `create`) and report the new record id and
  HubSpot URL. The agent keeps multi-turn session memory (Redis), so the proposal
  and the confirmation span two messages without any extra flow nodes.
- The builtin `emit.response` node (`send_reply`) routes the agent's reply back to
  the active webchat channel.
- The agent's tools (`hubspot_contacts`, `hubspot_deals`, `hubspot_companies`,
  `hubspot_tickets`, `hubspot_associate`) come from the `greentic.hubspot`
  design extension, pulled from `store.greentic.cloud` at run time. No `.wasm` is
  bundled into the demo.

## Components

| Node | Kind | Purpose |
|------|------|---------|
| `assistant` | `dw.agent` (Agentic Worker) | HubSpot CRM assistant agent; confirms creates in chat before writing |
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
