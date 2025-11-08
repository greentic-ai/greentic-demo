# greentic-demo

Single binary that bridges Bot Framework Activities and `greentic-runner` over NATS/JetStream. Packs are loaded once at startup and scoped per tenant.

## Layout
```
cmd/greentic-demo/       # executable entrypoint
src/                     # reusable library (config, logging, bridges)
packs/<tenant>/index.ygtc
env/.env.example         # developer defaults
docs/quickstart.md       # runbook
```

## Features
- Dev mode (`--dev`): loads `.env`, uses local NATS (`nats://127.0.0.1:4222`), writes human logs to `demo.log`, skips JWT.
- Prod mode: expects secrets via env (JWT + seed), enables structured logs (placeholder for `greentic-telemetry`).
- Pack loader: enumerates `packs/*/index.ygtc`, registers each tenant with the runner, and keeps going when individual packs fail. Every tenant **must** ship a `bindings.yaml`; secrets referenced there must be included via `RUNNER_ALLOWED_SECRETS`/`--allowed-secrets`.
- Runner bridge: converts Activities -> runner signals and back. Unit tests cover text, Adaptive Cards, and button invoke payloads.
- NATS bridge: subscribes to `messaging.activities.in.<tenant>`, calls the runner sequentially per tenant, and publishes responses to `.out.<tenant>`.
- Health monitor: background task logs ingress/egress/error counters per tenant every 30 seconds.

## Usage
```bash
cargo run --bin greentic-demo -- --dev --packs-dir ./packs --allowed-secrets TELEGRAM_BOT_TOKEN
```
Directory structure per tenant:

```
packs/<tenant>/
  index.ygtc          # pack component (flows)
  bindings.yaml       # host bindings (adapters, secrets, MCP tooling)
  tools/              # optional tool binaries referenced by bindings
```

Example `bindings.yaml`:

```yaml
tenant: customera
flow_type_bindings:
  messaging:
    adapter: bot-framework
    config: {}
    secrets:
      - TELEGRAM_BOT_TOKEN
mcp:
  store:
    kind: local-dir
    path: ./tools
  security:
    require_signature: false
  runtime:
    max_memory_mb: 128
    timeout_ms: 10000
    fuel: 50000000
  http_enabled: true
```

For production you typically omit `--dev` and provide:
```
export NATS_URL=nats://nats.internal:4222
export NATS_JWT=$(greentic-secrets read demo.nats.jwt)
export NATS_SEED=$(greentic-secrets read demo.nats.seed)
```

At runtime the binary resolves each secret by first checking env vars, then `GREENTIC_SECRETS_DIR/<NAME>`, and finally `greentic-secrets read <NAME>`. To feed greentic-telemetry that is preconfigured by the hosting environment, set `GREENTIC_TELEMETRY_CONFIG` (inline JSON) or `GREENTIC_TELEMETRY_CONFIG_FILE`; payloads describe OTLP endpoints, e.g.:
```json
{
  "service_name": "greentic-demo",
  "sampling": { "ratio": 1.0 },
  "otlp": {
    "endpoint": "https://telemetry.greentic.ai",
    "protocol": "grpc",
    "headers": { "authorization": "Bearer <token>" }
  }
}
```

See `docs/quickstart.md` for full instructions, subject naming, and tenant onboarding. Run `ci/local_check.sh` before pushing to mirror the GitHub Actions pipeline.
