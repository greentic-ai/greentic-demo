# Local tunnels & the "messages never arrive" trap

This note explains when a public tunnel (Cloudflare Tunnel / ngrok) is involved
in a demo, why it is a **local-development concern only**, and how to recognise
the one failure mode that used to look like success.

## When you need a tunnel (and when you don't)

External messaging providers — Teams, Slack, WebEx, Telegram — deliver inbound
events to your runtime over a **public HTTPS webhook URL**. When you run a demo
locally with `gtc start ./<demo>-bundle`, your runtime is on `127.0.0.1`, which
those providers cannot reach. To bridge that gap, `greentic-start` can start a
**quick tunnel** (`https://<random>.trycloudflare.com`, or an ngrok URL) and
register it as the provider webhook.

| Scenario | Tunnel needed? | How the public URL is provided |
|---|---|---|
| Local dev, external provider (Teams/Slack/WebEx/Telegram) | **Yes** | Quick tunnel auto-started by `greentic-start` |
| Local dev, **Webchat only** | No | Served directly from the local gateway |
| Cloud / AWS deploy | **No** | Real ingress; set `PUBLIC_BASE_URL`, choose **No tunnel** during setup |

For the AWS path, pick **`No tunnel`** during `gtc setup` and supply
`PUBLIC_BASE_URL` (see the `deep-research-demo` AWS notes in the
[README](../README.md)). Tunnel providers are not part of the production path.

## Properties of quick tunnels (why local-only)

- **Ephemeral URL.** A quick tunnel gets a *new random* hostname on every
  restart. Any provider webhook still pointing at the previous URL goes stale —
  re-run setup/registration after a restart if inbound stops working.
- **Best-effort availability.** `*.trycloudflare.com` quick tunnels are rate-
  limited and not SLA-backed. They are fine for a demo, not for production.
- **Not required for Webchat.** If a demo only uses Webchat, you do not need a
  tunnel at all.

## Known failure: `cloudflared setup tunnel URL did not become reachable`

Symptom during `gtc setup` with an external provider enabled:

```text
Failed to start setup tunnel: cloudflared setup tunnel URL did not become reachable:
https://<random>.trycloudflare.com
```

**This is not a greentic bug, and it is not fixable with a `cloudflared` flag.**
The free `*.trycloudflare.com` quick tunnel publishes a URL and the control
connection registers, but the **edge → cloudflared serve stream is closed by
the remote** (`accept stream listener encountered a failure` /
`Application error 0x0 (remote)`), so no visitor request is ever delivered.

Reproduced on 2026-06-23 against a known-good local origin (returns 200), with
every account-less Cloudflare lever exhausted:

| cloudflared option | edge colo | visitor `GET /` |
| --- | --- | --- |
| default (QUIC) | `nbo01` | HTTP 000 for 90s — never routed |
| `--protocol http2` | `jnb04` | never routed |
| `--region us` | `iad20` | never routed (`Application error 0x0 (remote)`) |

DNS resolved, TLS/HTTP-2 to the edge succeeded, and generic Cloudflare 443
worked — only the **account-less quick-tunnel data plane** failed, identically
across three colos and two protocols. This matches Cloudflare's own warning that
account-less quick tunnels have **"no uptime guarantee"** and that production use
needs a **pre-created named tunnel**.

### Fix (Cloudflare-native)

1. **Use a pre-created Cloudflare named tunnel** (account-backed) — the
   documented replacement for quick tunnels. It authenticates with your
   Cloudflare account, is not subject to the account-less throttling that breaks
   the quick-tunnel data plane, and gives a **stable hostname** (no per-restart
   URL drift). Point that hostname at the local gateway and use it as
   `PUBLIC_BASE_URL`.
   See <https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/>.
2. **Or supply a stable `PUBLIC_BASE_URL`** you already control (named tunnel,
   reverse proxy, or a cloud deploy) and choose **No tunnel** during setup.
3. **Retry** — quick tunnels are assigned per attempt; a fresh run *sometimes*
   lands a healthy edge, but this was not reliable in testing.

### Set up a named tunnel with a token (recommended)

A named tunnel uses a **connector token** from your Cloudflare account, so it is
not throttled like the account-less quick tunnel and keeps a **stable hostname**.

1. In the Cloudflare dashboard → **Zero Trust → Networks → Tunnels**, create a
   tunnel and copy its **token** (a long `eyJ...` string). Add a **public
   hostname** route on that tunnel — e.g. `demo.<your-domain>` → service
   `http://localhost:<gateway-port>` (the port `greentic-start` binds locally).
2. Run the connector yourself (leave it running alongside the demo):

   ```bash
   export CLOUDFLARE_TUNNEL_TOKEN=eyJ...        # the token from step 1
   cloudflared tunnel run --token "$CLOUDFLARE_TUNNEL_TOKEN"
   ```

3. Point the demo at that stable hostname and **do not** let it start its own
   quick tunnel — choose **No tunnel** during `gtc setup` and set:

   ```bash
   export PUBLIC_BASE_URL=https://demo.<your-domain>
   ```

Now external providers (Teams/Slack/WebEx/Telegram) register against the stable
named-tunnel hostname instead of the flaky ephemeral `*.trycloudflare.com` URL.
Cloudflare's named-tunnel docs:
<https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/>.

## The runtime failure mode to watch for

If the tunnel process starts but never becomes reachable, the runtime used to
log a single `Warn` ("not yet reachable, continuing anyway") buried in
`state/.../system.log` and otherwise carry on as if healthy. The visible symptom
was simply that **typed messages from the external provider never reached a
flow** — no error on screen, nothing obviously broken.

`greentic-start` now surfaces this clearly instead:

- the run summary marks the service `cloudflared (...) [... | status=UNREACHABLE]`
  instead of looking healthy, and
- an **`Error`**-level line is written explaining the consequence (inbound
  webhooks will not be delivered) and the remedy.

Startup intentionally still continues — an unreachable tunnel is **not** a hard
failure — so you can keep using anything that does not depend on the tunnel
(e.g. local Webchat).

### If you see `status=UNREACHABLE`

1. Check the tunnel log: `state/runtime/<tenant>.<team>/../cloudflared.log`
   (path is printed in the run summary).
2. Restart the demo to obtain a fresh tunnel URL, and re-register the provider
   webhook if you are testing Teams/Slack/WebEx/Telegram.
3. Try ngrok instead: `greentic-start start --bundle . --ngrok on`.
4. For anything beyond local dev, stop using a quick tunnel — set
   `PUBLIC_BASE_URL` to a stable public origin and choose **No tunnel**.

## Related

- Webchat-specific dispatch failure (runtime ↔ provider interface drift):
  [crates/pet-daycare-demo/ISSUE-webchat-ingress-drift.md](../crates/pet-daycare-demo/ISSUE-webchat-ingress-drift.md)
