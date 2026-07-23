# Webchat demo breakage — holistic root cause & fix plan

_Post-mortem + consolidated fix plan for the weather-mcp-demo / hr-onboarding
webchat regressions (`http://127.0.0.1:8080/v1/web/webchat/default/`)._

## TL;DR

This was never one bug. **Two migrations shipped without finishing**, and the
fallout is **four distinct problems**. Two are fixed (A, B). Two were only
uncovered late and are still open — and they are the ones that actually keep the
demo from rendering a weather card:

1. **Flow-engine contract breaks** on the env/revision path → **Changeset A** (fixed).
2. **Secrets writer/reader rendezvous** → **Changeset B** (fixed).
3. **The resolved API key never reaches the component** → **open** (real bug, proven).
4. **`gtc start` deploys additively; deployments collide on the default route** → **open** (real bug, proven).

Things we *thought* were bugs but were not: the "double card" (the user pressed
the button twice) and "the placeholder key is the whole story" (the key is
valid; the component just never receives it).

## Root cause

### Migration 1 — the env/revision serve-path (gtc #251 / greentic-start #400 family)

`gtc start <bundle>` used to boot a single, bundle-scoped server. Commit
**`4360bdd` — feat(start): route `gtc start <bundle>` through the environment
(B4b) (1.1.6) (#251)** rerouted it to **deploy into a shared environment**. That
move broke three flow-engine contract assumptions the compiled packs rely on
(→ Changeset A) **and** introduced the additive-deployment collision (→ #4).

### Migration 2 — the env-store secrets move (setup #226 / start #423)

Secrets moved to the shared env store, but the writer and reader disagreed on
path + env until Changeset B.

## The fixes

### Changeset A — restore the pack contract on the env-path (greentic-runner) — DONE

Tested, PR #611 (branch `fix/messaging-entry-flow-routing`, 1.1.7). Three seams,
each unit-covered:

| Symptom | Fix |
|---|---|
| Blank webchat / "flow type messaging is ambiguous" | entry-flow-aware routing (`entry_flow_by_type`, `tags_indicate_entry`) |
| Card emitted twice by the flow | `finalize_with` no longer re-appends the terminal emit |
| Button → welcome card | `alias_input_to_entry` in `template_context` + `build_routing_context` |

### Changeset B — finish the env-store secrets move (gtc + greentic-start) — DONE

- greentic-start (`test/webchat-full-local`): `open_dev_store_manager` +
  `dev_store_path` helpers resolve the shared env store; **T1 test** guards the
  writer↔reader rendezvous.
- gtc (`fix/gtc-secrets-env-pin`, off main, 1.1.9, compiles): drop the
  `GREENTIC_DEV_SECRETS_PATH` bundle-root override; pin `GREENTIC_ENV` on the
  setup/provider/op/wizard passthrough children.

### Dropped — `conv_dedup` rebuild

The visible "double" was the user pressing the button twice, not the TOCTOU race
conv_dedup targets. Dropped (recoverable at `818a091`).

## OPEN #3 — the WeatherAPI key is not provisioned where the component reads it

**Not a component, generator, or render bug — a secrets provisioning/scope
rendezvous.** The weather card fails because the key isn't in the store, at the
URI, the component's secrets host-function looks up. Proven:

- The user's key returns full weather via a **direct curl** → the key is **valid**.
- Reproduction test (`repro_get_weather_reply_shape`, greentic-start
  `messaging_app.rs`): the real `flow_get_weather` returns WeatherAPI **code 1002**
  ("not provided"), **not 2006** ("invalid") → the component sends WeatherAPI
  **no key at all**.
- The live `.greentic/dev/.dev.secrets.env` was a **0-byte file** — empty store.

### What the deployed component actually does (verified from the wasm)

Earlier hypothesis (stale component / missing `SecretStore` source) was **wrong**.
The deployed `weatherapi_current.component.wasm` (built May 15) **imports
`greentic:secrets-store/secrets-store@1.0.0` and calls `get`**, and carries the
secret key string `auth.param.get_weather.key`. So its `apply_auth_bindings`
resolution order is:

```
SecretStore { key: "auth.param.get_weather.key" }   # host fn — the working path
  -> Env { MCP_SECRET_AUTH_PARAM_GET_WEATHER_KEY }
  -> LegacyEnv { MCP_API_KEY }
```

It correctly asks the runtime via the host function (that is the "WASM secrets
read requested uri=…" log). The host returned **empty**, so it fell through to
the unset env vars and sent an empty `key=` param → 1002.

### Why the host returns empty — the real gap

The key is not present at the exact URI the component reads:
`secrets://<env>/<tenant>/<team>/weatherapi-pack/auth_param_get_weather_key`.
Two contributing factors:

1. **Empty/wiped store** — the dev store the host reads had no key (0 bytes).
2. **Tenant scope mismatch** — the secret's scope is `{env: runtime, tenant:
   runtime}`, so the component reads under the *deployment's* runtime tenant. The
   host logged the read at tenant `default`, but `gtc setup` persisted secrets
   under tenant `demo` (`[secrets] scope: env=local, tenant=demo`). Writer and
   component-reader disagree on tenant → miss → empty.

This is Changeset B's rendezvous problem, one level deeper: not just writer↔
`open_dev_store_manager`, but writer↔**the component's `secrets_store` host
lookup** (env + tenant + team + pack + key must all line up).

### Fix / next step

- Provision the key at the **exact** URI the component's host lookup uses —
  matching the deployment's runtime **env + tenant + team**. Confirm the
  deployment's runtime tenant/team, then `op secrets put` there (not a different
  tenant).
- Verify on the **live full server** with the 1002→render discriminator (a valid
  key reaching the component renders the card; a wrong tenant still 1002).
- **Harness caveat:** the in-process `run_app_flow` path does **not** provision
  the `host.secrets.required` lookup the way the full server does, so the repro
  test proves the *no-key* failure but cannot render even with a valid key seeded.
  A true green proof needs the full server boot (see T2).

## OPEN #4 — additive deployment collision

`gtc start <bundle>` (post-#251) **adds** a deployment to the shared env and never
supersedes. `env local` accumulated **three** deployments (weather-mcp-demo,
quickstart-demo, hr-onboarding-demo), all at `weight_bps: 10000`, all claiming
`/v1/web/webchat/default/`. First-deployed (weather) wins — which is why starting
hr-onboarding still showed the weather card.

### Follow-ups

1. **Make `gtc start <bundle>` supersede** prior deployments on the shared route
   (or scope each bundle to a distinct route/tenant) instead of piling up.
2. **Implement `gtc op env destroy`** for real. It is "not yet implemented" in
   the published 1.1.x operator/deployer; the locally checked-out operator
   (0.4.48) has no destroy verb at all, so this needs the published source tree +
   a toolchain release.
3. **Interim tool (shipped):** `scripts/gtc-env-nuke <env> [--purge] [--yes]` —
   stops the runtime, moves the env to a timestamped `.bak` (reversible), and
   only hard-deletes with `--purge`. Reproducible, safe replacement for hand
   `mv`/`rm`.

## Regression tests — make a migration break the build, not the demo

The root process failure: nothing exercised these contracts end-to-end.

- **T1 — setup env-store rendezvous** (greentic-start): implemented + passing,
  ships with Changeset B. Guards writer↔reader path/env agreement.
- **Reproduction test — `repro_get_weather_reply_shape`** (greentic-start): dual
  mode. Without `WEATHERAPI_TEST_KEY` it asserts the known auth-error shape
  (green in CI); with it, it seeds the key and asserts a rendered card. Currently
  reproduces OPEN #3 (no key reaches the component). Uses the 1002-vs-2006
  discriminator.
- **Changeset A seams** (greentic-runner): `entry_flow_by_type`, finalize
  no-double, `alias_input_to_entry`, `parse_envelopes` — already unit-covered.
- **T2 — full serve-path webchat e2e — TODO.** The only way to prove #3's fix
  and the render path end-to-end. Needs the full `gtc` server boot (the
  provider/gateway layer that injects `host.secrets.required`), or a WASM
  component fixture — not the minimal in-process runner path.

## Status

- [x] Changeset A — routing + finalize + `in.input`; unit-tested; PR #611
- [x] Changeset B — secrets rendezvous (gtc `fix/gtc-secrets-env-pin` 1.1.9 +
      greentic-start `test/webchat-full-local`); T1 passing
- [x] conv_dedup — dropped (double was a double-press)
- [x] `gtc-env-nuke` interim teardown tool — committed
- [ ] **OPEN #3 — key→component env injection** — the real card blocker; trace
      the runner's `MCP_SECRET_*` WASI-env injection for `host.secrets.required`
- [ ] **OPEN #4a — `gtc start` supersede** prior deployments on the shared route
- [ ] **OPEN #4b — implement `gtc op env destroy`** (published operator + release)
- [ ] **T2 — full serve-path e2e** — the green proof for #3
