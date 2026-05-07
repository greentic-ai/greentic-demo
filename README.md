# greentic-demo

Runnable Greentic demo catalog.

This repository provides prebuilt answer documents per demo so you can launch each one with the same 3-step flow:

1. `gtc wizard --answers https://github.com/greenticai/greentic-demo/releases/latest/download/<demo>-create-answers.json`
2. `gtc setup <bundle> --answers https://github.com/greenticai/greentic-demo/releases/latest/download/<demo>-setup-answers.json`
3. `gtc start <bundle>`

## Available Demos

The demos below have both `*-create-answers.json` and `*-setup-answers.json` published in releases and are runnable with the 3-step flow.
Standalone app-pack artifacts may also be published alongside these demos for reuse in other bundle flows.

### quickstart

Outcome:
- Starts a minimal assistant that shows a welcome card, an about card, and basic chat interactions.

Run:
```bash
gtc wizard --answers https://github.com/greenticai/greentic-demo/releases/latest/download/quickstart-create-answers.json
gtc setup ./quickstart-demo-bundle --answers https://github.com/greenticai/greentic-demo/releases/latest/download/quickstart-setup-answers.json
gtc start ./quickstart-demo-bundle
```

### hr-onboarding

Outcome:
- Runs an onboarding assistant for employee intake, checklist tracking, and document/access collection.

Run:
```bash
gtc wizard --answers https://github.com/greenticai/greentic-demo/releases/latest/download/hr-onboarding-create-answers.json
gtc setup ./hr-onboarding-demo-bundle --answers https://github.com/greenticai/greentic-demo/releases/latest/download/hr-onboarding-setup-answers.json
gtc start ./hr-onboarding-demo-bundle
```

### helpdesk-itsm

Outcome:
- Runs an IT helpdesk assistant with Jira-oriented ticket flows (create, status, escalation, KB lookup).

Run:
```bash
gtc wizard --answers https://github.com/greenticai/greentic-demo/releases/latest/download/helpdesk-itsm-create-answers.json
gtc setup ./helpdesk-itsm-demo-bundle --answers https://github.com/greenticai/greentic-demo/releases/latest/download/helpdesk-itsm-setup-answers.json
gtc start ./helpdesk-itsm-demo-bundle
```

### sales-crm

Outcome:
- Runs a sales assistant for lead qualification, pipeline visibility, and deal tracking.

Run:
```bash
gtc wizard --answers https://github.com/greenticai/greentic-demo/releases/latest/download/sales-crm-create-answers.json
gtc setup ./sales-crm-demo-bundle --answers https://github.com/greenticai/greentic-demo/releases/latest/download/sales-crm-setup-answers.json
gtc start ./sales-crm-demo-bundle
```

### supply-chain

Outcome:
- Runs an inventory/supply-chain assistant for stock checks, order tracking, and reorder workflows.

Run:
```bash
gtc wizard --answers https://github.com/greenticai/greentic-demo/releases/latest/download/supply-chain-create-answers.json
gtc setup ./supply-chain-demo-bundle --answers https://github.com/greenticai/greentic-demo/releases/latest/download/supply-chain-setup-answers.json
gtc start ./supply-chain-demo-bundle
```

### redbutton

Outcome:
- Runs a red-button response scenario that routes inbound events and triggers branch actions and incident hooks.

Run:
```bash
gtc wizard --answers https://github.com/greenticai/greentic-demo/releases/latest/download/redbutton-create-answers.json
gtc setup ./redbutton-demo-bundle --answers https://github.com/greenticai/greentic-demo/releases/latest/download/redbutton-setup-answers.json
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
gtc wizard --answers https://github.com/greenticai/greentic-demo/releases/latest/download/cloud-deploy-demo-create-answers.json
gtc setup ./cloud-deploy-demo-bundle --answers https://github.com/greenticai/greentic-demo/releases/latest/download/cloud-deploy-demo-setup-answers.json
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
gtc wizard --answers https://github.com/greenticai/greentic-demo/releases/latest/download/weather-mcp-demo-create-answers.json
gtc setup ./weather-mcp-demo-bundle --answers https://github.com/greenticai/greentic-demo/releases/latest/download/weather-mcp-demo-setup-answers.json
gtc start ./weather-mcp-demo-bundle
```

### deep-research-demo

Outcome:
- Runs a deep-research assistant with `Single Shot` and `Agentic` modes, adaptive-card planning, a final report flow, and an AWS-deployable bundle path.

Run locally:
```bash
gtc wizard --answers https://github.com/greenticai/greentic-demo/releases/latest/download/deep-research-demo-create-answers.json
gtc setup ./deep-research-demo-bundle --answers https://github.com/greenticai/greentic-demo/releases/latest/download/deep-research-demo-setup-answers.json
gtc start ./deep-research-demo-bundle
```

Run on AWS:
```bash
gtc wizard --answers https://github.com/greenticai/greentic-demo/releases/latest/download/deep-research-demo-aws-create-answers.json
gtc setup ./deep-research-demo-bundle --answers https://github.com/greenticai/greentic-demo/releases/latest/download/deep-research-demo-aws-setup-answers.json
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
- If S3 upload permissions are not available yet, you can use this fallback instead:
```bash
export GREENTIC_DEPLOY_BUNDLE_SOURCE="https://github.com/greenticai/greentic-demo/releases/download/v0.1.74/deep-research-demo.gtbundle?ts=1778100000"
gtc start ./deep-research-demo-bundle --target aws
```
- The AWS setup answers still expect runtime deployment variables such as `PUBLIC_BASE_URL` and `REDIS_URL` to be supplied during setup or deploy.

### telco-x-demo

Outcome:
- Runs a Telco-X assistant in Webchat with category menus, multi-playbook telco flows, and adaptive-card results for traffic, capacity, RCA, and service-assurance scenarios.

Run:
```bash
gtc wizard --answers https://github.com/greenticai/greentic-demo/releases/latest/download/telco-x-demo-create-answers.json
gtc setup ./telco-x-demo-bundle --answers https://github.com/greenticai/greentic-demo/releases/latest/download/telco-x-demo-setup-answers.json
gtc start ./telco-x-demo-bundle
```
