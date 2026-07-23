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

## OPEN #3 — the resolved WeatherAPI key never reaches the component

**This is the real reason the weather card doesn't render — not the key, not the
render path.** Proven, not assumed:

- The user's key returns full weather via a **direct curl** → the key is **valid**.
- A reproduction test (`repro_get_weather_reply_shape`, greentic-start
  `messaging_app.rs`) runs the real `flow_get_weather` through the real runner.
  With a **bogus** key seeded it returns WeatherAPI **code 1002** ("not
  provided"), **not 2006** ("invalid"). That discriminator proves the component
  sends WeatherAPI **no key at all** — the resolved secret never reaches the
  outbound request.
- The live `.greentic/dev/.dev.secrets.env` was a **0-byte file** — the key was
  never persisted there either.

### Mechanism (traced)

The generated `weatherapi_current` component (greentic-mcp-generator) reads the
key **only from a process/WASI env var**, via `apply_auth_bindings`:

```
AuthInjection::Query { name: "key" }
sources: [ Env { MCP_SECRET_AUTH_PARAM_GET_WEATHER_KEY }, LegacyEnv { MCP_API_KEY } ]
```

So the host must resolve `auth.param.get_weather.key` and **inject it as the WASI
env var `MCP_SECRET_AUTH_PARAM_GET_WEATHER_KEY`** into the component. The
"WASM secrets read requested" log shows the host *resolves* the secret, but the
value is not landing in that env var — so `std::env::var(...)` in the component
returns nothing and the `key=` query param goes out empty.

### Where to fix / next step

- Trace the runner's component-invocation env injection: where
  `secret_requirements` (scope `host.secrets.required`) are turned into the
  guest's WASI env (`MCP_SECRET_*`). Confirm the resolved value is actually set
  on the guest env, with the correct name derivation
  (`secret_key_env_var`: `MCP_SECRET_` + upper(key)).
- **Harness caveat:** the in-process `run_app_flow` / `run_pack_with_options`
  path does **not** provision `host.secrets.required` (a provider/gateway layer
  only runs in the full `gtc` server), so the repro test can prove the *no-key*
  failure but cannot render a card even with a valid key. A true green proof
  needs the full server boot (see T2).

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
