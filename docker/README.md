# greentic-demo telemetry stack

Reusable local OpenTelemetry stack for inspecting what any greentic-demo bundle emits. Compose file ships an OTel Collector, Prometheus, and Grafana — pointed at each other so a single `docker compose up` gets you a working dashboard.

Not tied to any one demo. Any bundle whose runner has `TELEMETRY_EXPORT=otlp-grpc` (or `otlp-http`) set and `OTLP_ENDPOINT` aimed at this collector will start pushing.

## Start the stack

```bash
docker compose --project-directory ./docker -f ./docker/docker-compose.yml up -d
```

Tear down with `docker compose --project-directory ./docker -f ./docker/docker-compose.yml down`.

## Point a demo at it

```bash
export TELEMETRY_EXPORT=otlp-grpc
export OTLP_ENDPOINT=http://localhost:4317
gtc start ./weather-mcp-demo-bundle    # or any other demo bundle
```

OTLP HTTP works too — set `TELEMETRY_EXPORT=otlp-http` and `OTLP_ENDPOINT=http://localhost:4318`.

## What lands where

| Signal | Path | How to look at it |
|---|---|---|
| Traces (host spans + provider invocations) | OTel Collector → `debug` exporter | `docker logs -f greentic-demo-otelcol` |
| Metrics (host counters, OTel SDK internals) | Collector → Prometheus scrape on `:8889` → Prometheus on `:9090` | `http://localhost:9090` or via Grafana |
| Logs (anything emitted as OTLP logs) | Collector → Loki on `:3100` | Grafana Explore → Loki, or `curl http://localhost:3100/loki/api/v1/query_range` |
| Grafana dashboard surface | Anonymous admin, Prometheus + Loki pre-wired | `http://localhost:3000` |

See [`PLAYBOOK.md`](./PLAYBOOK.md) for copy-pasteable Prometheus + Loki
queries grouped by KPI (throughput, latency, errors, active conversations).

## Endpoints summary

| Port | Service | Notes |
|---|---|---|
| 4317 | OTel Collector — OTLP gRPC | greentic-runner default for `otlp-grpc` |
| 4318 | OTel Collector — OTLP HTTP | greentic-runner default for `otlp-http` |
| 8889 | OTel Collector — Prometheus exporter | scraped by Prometheus |
| 9090 | Prometheus UI | query browser |
| 3100 | Loki | log ingest + query |
| 3000 | Grafana UI | anonymous admin |

## Quick checks once a demo is running

```bash
# 1. Confirm the collector is receiving anything at all
docker logs --tail 20 greentic-demo-otelcol | grep -E "ResourceSpans|ResourceMetrics|ResourceLogs"

# 2. Look at scraped metrics
curl -s http://localhost:8889/metrics | head -40

# 3. Prometheus query examples
#    http://localhost:9090/graph
#    queries to try:
#      greentic_messages_total
#      rate(greentic_flow_executions_total[1m])
#      up{job="otel-collector"}
```

## Notes

- Prometheus retention is set to 1h in `docker-compose.yml` to keep local disk usage tiny. Bump if you need a longer window.
- The `debug` exporter in `otel-collector-config.yaml` uses `sampling_initial: 5, sampling_thereafter: 50` so logs don't drown the terminal during long-running demos. Drop the sampling block to see every event.
- No persistence volumes — restarting the stack wipes the Prometheus TSDB and Grafana state. Add named volumes if needed.
