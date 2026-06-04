# greentic-demo

Runnable Greentic demo catalog.

This repository publishes demo packs and answer documents to GHCR as OCI artifacts so you can launch each demo with the same 3-step flow:

1. `gtc wizard --answers oci://ghcr.io/greenticai/answers/<demo>/create:latest`
2. `gtc setup --answers oci://ghcr.io/greenticai/answers/<demo>/setup:latest <bundle>`
3. `gtc start <bundle>`

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
- If S3 upload permissions are not available yet, you can use this fallback instead:
```bash
export GREENTIC_DEPLOY_BUNDLE_SOURCE="https://github.com/greenticai/greentic-demo/releases/download/v0.1.74/deep-research-demo.gtbundle?ts=1778100000"
gtc start ./deep-research-demo-bundle --target aws
```
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

Run:
```bash
gtc wizard --answers oci://ghcr.io/greenticai/answers/telco-x-demo/create:latest
gtc setup --answers oci://ghcr.io/greenticai/answers/telco-x-demo/setup:latest ./telco-x-demo-bundle
gtc start ./telco-x-demo-bundle
```
