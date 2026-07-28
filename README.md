# greentic-demo

Runnable Greentic demo catalog.

## Install the toolchain

```bash
cargo binstall gtc
gtc install
gtc doctor
```

`gtc install` resolves the stable toolchain manifest and installs every binary
at its pinned version. Run it again whenever a new stable release lands —
demos are only tested against the current stable lane.

## Launch a demo

This repository publishes demo packs and answer documents to GHCR as OCI
artifacts, so every demo launches the same way. Either run the four steps
yourself:

1. `gtc wizard --answers oci://ghcr.io/greenticai/answers/<demo>/create:latest`
2. `gtc setup --answers oci://ghcr.io/greenticai/answers/<demo>/setup:latest <bundle>`
3. `gtc start <bundle>`

…or chain install → wizard → setup → start with one command:

```bash
gtc up \
  --answers       oci://ghcr.io/greenticai/answers/<demo>/create:latest \
  --setup-answers oci://ghcr.io/greenticai/answers/<demo>/setup:latest
```

`gtc up` ends in a foreground server, exactly like `gtc start`. Both answer
documents are required — it never guesses the second one. Setup flags
(`--tenant`, `--team`, `--env`, `--advanced`) are **not** forwarded; run the
steps separately if you need them. Anything after `--` goes to the start step,
so `gtc up … -- --open-webchat` opens the browser once the listener is up.
`--dry-run` prints every step and the resolved bundle directory without running
anything.

## Opening the chat UI

Each demo serves its webchat UI from a pack, and `gtc start` prints the URLs on
boot:

```
serving 1 revision(s) for env `local` across 1 deployment(s) on http://127.0.0.1:8080. Press Ctrl+C to stop.
UI: http://127.0.0.1:8080/v1/web/webchat/default/ → default bundle `helpdesk-itsm-demo`
UI: http://127.0.0.1:8080/v1/web/webchat/default/helpdesk-itsm-demo/ (default)
```

The URL grammar is `/v1/web/webchat/{tenant}[/{bundle}[/{flow}]]/`:

| URL | Resolves to |
|-----|-------------|
| `/v1/web/webchat/default/` | the environment's default bundle |
| `/v1/web/webchat/default/<bundle>/` | that bundle specifically |
| `/v1/web/webchat/default/<bundle>/<flow>/` | one flow inside that bundle |

The tenant segment is required. Bundles that ship no webchat UI pack are called
out rather than silently omitted:

```
no webchat UI pack in bundle(s) hr-chat — messaging endpoints only, no browser URL
```

`GET /chat` redirects to the default bundle's webchat URL whenever a pack
provides the UI; the built-in console is only served when none does. Pass
`--open-webchat` to `gtc start` to open the default bundle in your browser, or
`--open-webchat=<bundle-id>` for a specific one.

To add a messaging provider to a running environment without rebuilding the
bundle, use `gtc provider add|list|remove`.

## Available Demos

The demos below have both create and setup answer artifacts published as raw JSON OCI artifacts. Demo packs are published under `oci://ghcr.io/greenticai/packs/demos/<pack>:latest`.

### quickstart

Outcome:
- Starts a minimal assistant that shows a welcome card, an about card, and basic chat interactions.

Run:
```bash
gtc wizard --answers oci://ghcr.io/greenticai/answers/quickstart/create:latest
gtc setup --answers oci://ghcr.io/greenticai/answers/quickstart/setup:latest ./quickstart-demo-bundle
gtc start ./quickstart-demo-bundle
```

### quickstart-event

Outcome:
- Runs the four Greentic event providers side by side — webhook ingress, cron
  timer, SendGrid email, and Twilio SMS.

Run:
```bash
gtc wizard --answers oci://ghcr.io/greenticai/answers/quickstart-event/create:latest
gtc setup --answers oci://ghcr.io/greenticai/answers/quickstart-event/setup:latest ./quickstart-event-demo-bundle
gtc start ./quickstart-event-demo-bundle --ngrok on
```

Email and SMS need provider credentials (`sendgrid_api_key` / `from_email`,
`account_sid` / `auth_token` / `from_number`); webhook and timer need none. See
[`crates/quickstart-event-demo/README.md`](crates/quickstart-event-demo/README.md).

### hr-onboarding

Outcome:
- Runs an onboarding assistant for employee intake, checklist tracking, and document/access collection.

Run:
```bash
gtc wizard --answers oci://ghcr.io/greenticai/answers/hr-onboarding/create:latest
gtc setup --answers oci://ghcr.io/greenticai/answers/hr-onboarding/setup:latest ./hr-onboarding-demo-bundle
gtc start ./hr-onboarding-demo-bundle
```

### helpdesk-itsm

Outcome:
- Runs an IT helpdesk assistant with Jira-oriented ticket flows (create, status, escalation, KB lookup).

Run:
```bash
gtc wizard --answers oci://ghcr.io/greenticai/answers/helpdesk-itsm/create:latest
gtc setup --answers oci://ghcr.io/greenticai/answers/helpdesk-itsm/setup:latest ./helpdesk-itsm-demo-bundle
gtc start ./helpdesk-itsm-demo-bundle
```

### sales-crm

Outcome:
- Runs a sales assistant for lead qualification, pipeline visibility, and deal tracking.

Run:
```bash
gtc wizard --answers oci://ghcr.io/greenticai/answers/sales-crm/create:latest
gtc setup --answers oci://ghcr.io/greenticai/answers/sales-crm/setup:latest ./sales-crm-demo-bundle
gtc start ./sales-crm-demo-bundle
```

### supply-chain

Outcome:
- Runs an inventory/supply-chain assistant for stock checks, order tracking, and reorder workflows.

Run:
```bash
gtc wizard --answers oci://ghcr.io/greenticai/answers/supply-chain/create:latest
gtc setup --answers oci://ghcr.io/greenticai/answers/supply-chain/setup:latest ./supply-chain-demo-bundle
gtc start ./supply-chain-demo-bundle
```

### redbutton

Outcome:
- Runs a red-button response scenario that routes inbound events and triggers branch actions and incident hooks.

Run:
```bash
gtc wizard --answers oci://ghcr.io/greenticai/answers/redbutton/create:latest
gtc setup --answers oci://ghcr.io/greenticai/answers/redbutton/setup:latest ./redbutton-demo-bundle
gtc start ./redbutton-demo-bundle
```

To send a message to the webhook for testing:
```bash
curl -i -X POST http://127.0.0.1:8080/v1/events/ingress/greentic.events.webhook/default/default \
  -H "content-type: application/json" \
  -d '{"event":"red_button","source":"demo","severity":"critical"}'
```

### cloud-deploy-demo

Outcome:
- Runs a deployment-focused demo bundle that includes messaging, events, state, and deploy-provider wiring.

Run:
```bash
gtc wizard --answers oci://ghcr.io/greenticai/answers/cloud-deploy-demo/create:latest
gtc setup --no-ui --answers oci://ghcr.io/greenticai/answers/cloud-deploy-demo/setup:latest ./cloud-deploy-demo-bundle
gtc start ./cloud-deploy-demo-bundle
```

Notes:
- This remains a minimal deployment smoke demo.
- For the richer AWS-ready demo flow, use `deep-research-demo` below.

### weather-mcp-demo

Outcome:
- Runs a weather assistant that fetches current conditions and forecast data, then renders adaptive-card responses.

Run:
```bash
gtc wizard --answers oci://ghcr.io/greenticai/answers/weather-mcp-demo/create:latest
gtc setup --answers oci://ghcr.io/greenticai/answers/weather-mcp-demo/setup:latest ./weather-mcp-demo-bundle
gtc start ./weather-mcp-demo-bundle
```

### deep-research-demo

Outcome:
- Runs a deep-research assistant with `Single Shot` and `Agentic` modes, adaptive-card planning, a final report flow, and an AWS-deployable bundle path.

Run locally:
```bash
gtc wizard --answers oci://ghcr.io/greenticai/answers/deep-research-demo/create:latest
gtc setup --answers oci://ghcr.io/greenticai/answers/deep-research-demo/setup:latest ./deep-research-demo-bundle
gtc start ./deep-research-demo-bundle
```

Run on AWS:
```bash
gtc wizard --answers oci://ghcr.io/greenticai/answers/deep-research-demo/create-aws:latest
gtc setup --answers oci://ghcr.io/greenticai/answers/deep-research-demo/setup-aws:latest ./deep-research-demo-bundle
gtc start ./deep-research-demo-bundle --target aws --upload-bundle s3://<your-bucket>/<prefix>/
```

Notes:
- The local create/setup path is intentionally separate from the AWS create/setup path.
- The local setup answers now default to the OpenAI path and expect `OPENAI_API_KEY` to be available during setup.
- If you want to use Ollama locally instead, download it from `https://ollama.com/download`, install it, then override the provider URL/model during `gtc setup`.
- The AWS setup answers use the OpenAI path and expect `OPENAI_API_KEY` to be available during setup.
- For cloud deploy, choose `No tunnel` during setup; tunnel providers are not required for the AWS path.
- If you want to use OpenAI, use the OpenAI-compatible base URL `https://api.openai.com/v1` during `gtc setup`.
- You can create or manage your OpenAI API keys at `https://platform.openai.com/api-keys`.
- If you want to use another OpenAI-compatible provider, supply that provider's compatible base URL and API key secret during `gtc setup`.
- The preferred AWS path is `--upload-bundle s3://...`, with no extra env vars if `aws` CLI is already configured and has `s3:GetObject` / `s3:PutObject` access to that prefix.
- If S3 upload permissions are not available yet, point the deploy at the
  published bundle instead:
```bash
gtc start ./deep-research-demo-bundle --target aws \
  --deploy-bundle-source https://github.com/greenticai/greentic-demo/releases/latest/download/deep-research-demo-bundle.gtbundle
```
  `GREENTIC_DEPLOY_BUNDLE_SOURCE` is the environment-variable equivalent of that
  flag if you would rather export it once.
- The AWS setup answers still expect runtime deployment variables such as `PUBLIC_BASE_URL` and `REDIS_URL` to be supplied during setup or deploy.

### pet-daycare-demo

Outcome:
- Runs a pet-daycare front-desk assistant with fast2flow free-text routing across 7 cards plus a live tool call into the Swagger petstore API.

Run:
```bash
gtc wizard --answers demos/pet-daycare-demo-create-answers.json
gtc setup  --answers demos/pet-daycare-demo-setup-answers.json ./pet-daycare-demo-bundle
FAST2FLOW_MIN_CONFIDENCE=0.05 gtc start ./pet-daycare-demo-bundle
```

`FAST2FLOW_MIN_CONFIDENCE=0.05` relaxes the default BM25 threshold (0.5) for the short utterances shipped in this demo's `assets/intent-index.json`.

### telco-x-demo

Outcome:
- Runs a Telco-X assistant in Webchat with category menus, multi-playbook telco flows, and adaptive-card results for traffic, capacity, RCA, and service-assurance scenarios.
- Uses embedded Telco-X demo data by default. The presentation component can also receive an external operator profile (`resolver_catalog_json` + `adapter_fixtures_json`) so operator-specific data lives outside the generic Telco-X layer.

Reference operator profile assets:
- `https://github.com/greentic-biz/demo-operator-telco/releases/latest/download/resolver_catalog.json`
- `https://github.com/greentic-biz/demo-operator-telco/releases/latest/download/adapter_fixtures.json`
- `https://github.com/greentic-biz/demo-operator-telco/releases/latest/download/playbook_config.json`
- `https://github.com/greentic-biz/demo-operator-telco/releases/latest/download/component_registry.yaml`

Run:
```bash
gtc wizard --answers oci://ghcr.io/greenticai/answers/telco-x-demo/create:latest
gtc setup --answers oci://ghcr.io/greenticai/answers/telco-x-demo/setup:latest ./telco-x-demo-bundle
gtc start ./telco-x-demo-bundle
```

Note: `demo-operator-telco` is currently private. For external users, mirror these assets to a public release or OCI location before publishing the demo instructions.

### github-review-demo

Outcome:
- OAuth bake-in demo: a GitHub Review Assistant that walks org → repo → open PRs / failed CI / releases, every step a real MCP call against the OAuth-aware `github_reports` component. On the first call with no token, the component self-gates and the runtime's **native OAuth engine** (PKCE + refresh) delivers a GitHub sign-in card — no OIDC provider is bundled. The card under test is the runtime-delivered sign-in card.
- Author prerequisite: a GitHub OAuth App (Settings → Developer settings → OAuth Apps) with authorization callback URL `http://localhost:8080/oauth/callback/github`. Enter the `client_id` / `client_secret` once at setup (scopes `repo`, `read:org`); the customer only signs in.

Run:
```bash
gtc wizard --answers oci://ghcr.io/greenticai/answers/github-review-demo/create:latest
gtc setup --answers oci://ghcr.io/greenticai/answers/github-review-demo/setup:latest ./github-review-demo-bundle
gtc start ./github-review-demo-bundle
```

### agentic-research-tavily-demo

Outcome:
- Runs an **Agentic Worker** (`dw.agent`) research assistant in WebChat: greets with an inline Adaptive Card, then answers questions by searching the live web with two Tavily tools (`tavily_search` + `tavily_extract`) and cites its sources. The agent keeps multi-turn memory in Redis, so follow-up questions work with no extra flow nodes.

Requirements:
- Redis on `127.0.0.1:6379` (`brew services start redis`) — the `dw.agent` node is disabled without it.
- An LLM key (DeepSeek by default) and a Tavily API key (from `https://tavily.com`).

Run:
```bash
gtc wizard --answers oci://ghcr.io/greenticai/answers/agentic-research-tavily-demo/create:latest
gtc setup --answers oci://ghcr.io/greenticai/answers/agentic-research-tavily-demo/setup:latest ./agentic-research-tavily-demo-bundle
gtc start ./agentic-research-tavily-demo-bundle
```

`gtc setup` prompts for the DeepSeek key and the Tavily API key once and stores them in the bundle; `gtc start` then needs no environment variables.

Notes:
- The Tavily tools resolve from `store.greentic.cloud` (the built-in default store).
- For crate details and the design/build notes, see [`crates/agentic-research-tavily-demo/README.md`](crates/agentic-research-tavily-demo/README.md) and [`docs/superpowers/specs/2026-06-28-tavily-demo-adaptive-cards-design.md`](docs/superpowers/specs/2026-06-28-tavily-demo-adaptive-cards-design.md).

### agentic-hubspot-crm-demo

Outcome:
- Runs an **Agentic Worker** (`dw.agent`) waiting-list assistant in WebChat: greets with an inline Adaptive Card, collects a contact's name/email/company, **confirms the fields before writing** (asks for `yes`), then creates a **HubSpot CRM contact** via the `hubspot_contacts` tool and reports the new contact id + URL.

Requirements:
- Redis on `127.0.0.1:6379` (`brew services start redis`).
- An LLM key (DeepSeek by default) and a HubSpot connection — a Private App token (`pat-…`, scopes `crm.objects.contacts.read` + `crm.objects.contacts.write`) or an OAuth app.

Run:
```bash
gtc wizard --answers oci://ghcr.io/greenticai/answers/agentic-hubspot-crm-demo/create:latest
gtc setup --answers oci://ghcr.io/greenticai/answers/agentic-hubspot-crm-demo/setup:latest ./agentic-hubspot-crm-demo-bundle
gtc start ./agentic-hubspot-crm-demo-bundle
```

`gtc setup` prompts for the DeepSeek key and the HubSpot connection (Private App token or OAuth) once and stores them in the bundle; `gtc start` then needs no environment variables.

Notes:
- The `greentic.hubspot` tool resolves from `store.greentic.cloud` (the built-in default store).
- Using HubSpot OAuth instead of a Private App token? Pick "OAuth" during `gtc setup` and connect there.
- For crate details and the design/build notes, see [`crates/agentic-hubspot-crm-demo/README.md`](crates/agentic-hubspot-crm-demo/README.md) and [`docs/superpowers/specs/2026-06-28-hubspot-crm-demo-design.md`](docs/superpowers/specs/2026-06-28-hubspot-crm-demo-design.md).

## Troubleshooting

- **External messages (Teams/Slack/WebEx/Telegram) never arrive locally** — a
  quick tunnel may have failed to come up. Quick tunnels are a local-dev
  convenience only; cloud/AWS uses `PUBLIC_BASE_URL` + `No tunnel`. See
  [docs/local-tunnels.md](docs/local-tunnels.md).
