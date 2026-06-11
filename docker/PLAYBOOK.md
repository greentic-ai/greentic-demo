# greentic telemetry playbook

Prometheus + Loki queries for inspecting any greentic-demo bundle from a
product/SRE lens — "Uber-style" KPIs (throughput, latency, errors, active
work) rather than raw engine internals.

Assumes the local stack from `docker-compose.yml` is up:

```bash
docker compose --project-directory ./docker -f ./docker/docker-compose.yml up -d
```

Grafana → http://localhost:3000 (anonymous admin). Open **Explore**, pick the
datasource at the top, paste a query.

> Note: metric names appear with a doubled `greentic_greentic_` prefix because
> the OTel collector's prometheus exporter prepends `namespace: greentic` to
> names that already start with `greentic.`. Drop the `namespace:` line in
> `otel-collector-config.yaml` to flatten — until then, queries below use the
> live names.

---

## Throughput — "how busy is the runner?"

| KPI | Query | Datasource |
|---|---|---|
| HTTP requests per second, per route | `sum by (route) (rate(greentic_greentic_http_requests_total[1m]))` | Prometheus |
| Flow executions per second | `rate(greentic_greentic_flow_executions_total[1m])` | Prometheus |
| Flow executions per second, by flow | `sum by (flow_id) (rate(greentic_greentic_flow_executions_total[1m]))` | Prometheus |
| New conversations per minute | `60 * rate(greentic_greentic_session_starts_total[5m])` | Prometheus |
| Provider invocations per second, by op | `sum by (op, provider) (rate(greentic_greentic_provider_invocations_total[1m]))` | Prometheus |

Uber analogy: *rides requested/sec*, *driver dispatches/sec*, *trips
completed/sec*.

---

## Concurrency — "how much is in flight right now?"

| KPI | Query | Datasource |
|---|---|---|
| Active conversations | `greentic_greentic_conversations_active` | Prometheus |
| Active conversations, per tenant | `sum by (tenant) (greentic_greentic_conversations_active)` | Prometheus |

Uber analogy: *drivers currently on a trip*.

---

## Latency — "how fast does each step run?"

| KPI | Query | Datasource |
|---|---|---|
| p95 HTTP latency, by route | `histogram_quantile(0.95, sum by (le, route) (rate(greentic_greentic_http_request_duration_ms_milliseconds_bucket[5m])))` | Prometheus |
| p99 flow duration, by flow_id | `histogram_quantile(0.99, sum by (le, flow_id) (rate(greentic_greentic_flow_duration_ms_milliseconds_bucket[5m])))` | Prometheus |
| Median provider-op duration, by op | `histogram_quantile(0.5, sum by (le, op, provider) (rate(greentic_greentic_provider_op_duration_ms_milliseconds_bucket[5m])))` | Prometheus |
| Average flow duration (ms) | `sum(rate(greentic_greentic_flow_duration_ms_milliseconds_sum[5m])) / sum(rate(greentic_greentic_flow_duration_ms_milliseconds_count[5m]))` | Prometheus |

Uber analogy: *pickup ETA p95*, *trip duration p99*.

---

## Errors — "what's going wrong?"

| KPI | Query | Datasource |
|---|---|---|
| HTTP 5xx rate, by route | `sum by (route) (rate(greentic_greentic_http_requests_total{status_code=~"5.."}[5m]))` | Prometheus |
| HTTP 4xx rate, by route | `sum by (route) (rate(greentic_greentic_http_requests_total{status_code=~"4.."}[5m]))` | Prometheus |
| Failed flow ratio | `sum(rate(greentic_greentic_flow_executions_total{status="err"}[5m])) / sum(rate(greentic_greentic_flow_executions_total[5m]))` | Prometheus |
| Failed provider invocations, by provider | `sum by (provider, op) (rate(greentic_greentic_provider_invocations_total{status="err"}[5m]))` | Prometheus |
| Error log volume, by scope | `sum by (scope_name) (rate({service_name="weather-mcp-demo-observer", severity_text="ERROR"}[5m]))` | Loki |

Uber analogy: *failed dispatches/sec*, *cancellation rate*.

---

## Logs — "what just happened, in plain text?"

Same Grafana Explore screen, switch the datasource to **Loki**:

| Question | Query |
|---|---|
| All logs from this bundle | `{service_name="weather-mcp-demo-observer"}` |
| Only the engine crate | `{service_name="weather-mcp-demo-observer", scope_name="greentic_runner_host::runner::engine"}` |
| Only errors | `{service_name="weather-mcp-demo-observer", severity_text="ERROR"}` |
| Anything mentioning `flow.execute` | `{service_name="weather-mcp-demo-observer"} \|= "flow.execute"` |
| Logs for a specific flow | `{service_name="weather-mcp-demo-observer"} \|~ "flow_get_weather"` |
| Log volume per scope (rate) | `sum by (scope_name) (rate({service_name="weather-mcp-demo-observer"}[1m]))` |

`service_name` is set by the bundle's `telemetry.service_name` (or
`OTEL_SERVICE_NAME`). For other demos, substitute the right value.

---

## What ships these metrics

| Metric | Where it's emitted | What labels you get |
|---|---|---|
| `greentic.http.requests` | `greentic-start::http_ingress::handle_request` | `method`, `route` (normalised), `status_code` |
| `greentic.http.request_duration_ms` | same — histogram alongside the counter | same |
| `greentic.session.starts` | `greentic-start::http_ingress::websocket::serve_session` | `tenant`, `provider` |
| `greentic.conversations.active` | same — UpDownCounter, +1 on connect, -1 on drop | `tenant`, `provider` |
| `greentic.flow.executions` | `greentic-runner-host::runner::engine::execute` | `tenant`, `flow_id`, `status` |
| `greentic.flow.duration_ms` | same — histogram | `tenant`, `flow_id`, `status` |
| `greentic.provider.invocations` | `greentic-runner-host::runner::engine::execute_provider_invoke` | `tenant`, `provider`, `op`, `status` |
| `greentic.provider.op_duration_ms` | same — histogram | same |

If a metric is missing from Prometheus: nothing has exercised that code path
yet. Drive some webchat traffic, then re-query.

---

## Building a dashboard

Quick path: clone the **Explore** panels into a dashboard via **Add → Add to
dashboard** in the top-right of Explore. Three rows that map nicely:

1. **Throughput** row: stack the HTTP-rps query, flow-rps query, and
   new-conversations-per-minute query in a time-series panel.
2. **Latency** row: one time-series with p50/p95/p99 of HTTP duration via
   `histogram_quantile(0.5/0.95/0.99, ...)`; one for flow duration.
3. **Health** row: stat panel showing `greentic_greentic_conversations_active`
   (gauge style), a stat panel for failed-flow ratio, and a logs panel from
   Loki filtered to `severity_text="ERROR"`.

Save the dashboard, then commit the exported JSON to
`docker/grafana-dashboards/` and provision it via Grafana's dashboards
provisioning if you want it to come up automatically.
