# greentic-demo quickstart

## Prerequisites
- Rust toolchain (1.78+ recommended)
- Local NATS/JetStream stack ("stack-up" target from greentic-messaging repo)
- Sample packs placed under `./packs/<tenant>/index.ygtc`

## Developer mode (`--dev`)
1. Copy `env/.env.example` to `.env` or `env/.env` and adjust values.
2. Start the messaging stack from `greentic-messaging` (JetStream + webchat helpers).
3. In this repo run:
   ```bash
   cargo run --bin greentic-demo -- --dev --packs-dir ./packs
   ```
4. Point the greentic webchat demo to `demo.greentic.ai/token?tenant=customera`.
5. Send a message. You should see the ingress activity on `messaging.activities.in.customera` and the echo reply on `.out.customera`.

Developer mode specifics:
- Loads `.env` (or `env/.env`) before parsing env variables.
- Defaults to `nats://127.0.0.1:4222` with no JWT.
- Logs stream into `./demo.log` (human-readable).

## Production mode (default)
- Do not pass `--dev`.
- Secrets must come from `greentic-secrets` (or equivalent):
  - `NATS_URL`
  - `NATS_JWT`
  - `NATS_SEED` (or `NATS_NKEY_SEED`)
- The binary will refuse to start if JWT material is missing.
- Logging switches to structured JSON (placeholder for greentic-telemetry).
- `greentic-demo` looks for secrets in this order: exported env var, `GREENTIC_SECRETS_DIR/<name>` file, then `greentic-secrets read <name>` CLI.
- Preconfigured telemetry can be passed via `GREENTIC_TELEMETRY_CONFIG` (inline payload) or `GREENTIC_TELEMETRY_CONFIG_FILE=/path/to/payload`; dev mode logs a warning when parsing fails, prod mode treats it as fatal. Payloads are JSON shaped like:
  ```json
  {
    "service_name": "greentic-demo-prod",
    "sampling": { "ratio": 0.25 },
    "otlp": {
      "endpoint": "https://telemetry.greentic.ai",
      "protocol": "grpc",
      "headers": { "authorization": "Bearer <token>" }
    }
  }
  ```
- Use `RUNNER_ALLOWED_SECRETS=SECRET1,SECRET2` (or `--allowed-secrets SECRET`) to control the allowlist injected into generated bindings so packs can read the secrets they need.

## Subject naming
Subjects follow `messaging.activities.{direction}.{tenant}` by default:
- Ingress: `messaging.activities.in.<tenant>`
- Egress: `messaging.activities.out.<tenant>`
You can override the prefix via `--subject-prefix` or `SUBJECT_PREFIX` when integrating with alternate topologies.

## Adding/removing tenants
1. Drop a new pack folder under `./packs/<tenant>/index.ygtc`.
2. Add `bindings.yaml` next to `index.ygtc`. The file describes flow adapters and allowed secrets (see example below).
3. Restart the binary (packs are only loaded at startup). Missing bindings cause the tenant to be skipped with an error.

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

## Health & telemetry
- Minimal connect/subscription logs are printed on startup.
- Each ingress/egress activity log is tagged with `tenant`, `kind`, and `activity_id` to make it easier to correlate traces later. A background health reporter also logs per-tenant ingress/egress/error counters every 30 seconds.
- Prod mode keeps trace IDs from `channelData.traceId` or `conversation.id` and re-attaches them to runner responses.
