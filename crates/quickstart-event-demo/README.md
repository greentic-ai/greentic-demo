# Quickstart Event Demo

Demonstrates all Greentic event providers working together:

- **Webhook** — Receive HTTP POST events from external services
- **Timer** — Cron-scheduled events
- **Email (SendGrid)** — Send transactional emails
- **SMS (Twilio)** — Send SMS messages

## Quick Start

```bash
# Create bundle
gtc wizard --answers oci://ghcr.io/greenticai/answers/quickstart-event/create:latest

# Setup providers
gtc setup --answers oci://ghcr.io/greenticai/answers/quickstart-event/setup:latest ./quickstart-event-demo-bundle

# Start
gtc start ./quickstart-event-demo-bundle --ngrok on
```

## Test Webhook

The ingress route is `/v1/events/ingress/{provider_id}/{tenant}/{team}`:

```bash
curl -X POST https://<ngrok-url>/v1/events/ingress/greentic.events.webhook/default/default \
  -H 'Content-Type: application/json' \
  -d '{"message": "Hello from webhook!", "source": "test"}'
```

## Providers

| Provider | OCI Reference | Required Secrets |
|----------|--------------|-----------------|
| Webhook | `events-webhook` | None (optional: secret_key for HMAC validation) |
| Timer | `events-timer` | None |
| Email | `events-email-sendgrid` | `sendgrid_api_key`, `from_email` |
| SMS | `events-sms-twilio` | `account_sid`, `auth_token`, `from_number` |
