# Webchat demo breakage — holistic root cause & fix plan

_Post-mortem + consolidated fix plan for the weather-mcp-demo webchat regression
(`http://127.0.0.1:8080/v1/web/webchat/default/`)._

## TL;DR

The demo did not break in five random ways. **Two migrations shipped without
finishing**, and every visible symptom falls out of one of them. The fixes group
into exactly two coherent changesets — plus one thing that is genuinely the
demo's own responsibility (a valid API key + an error card).

## Root cause

### Migration 1 — the env/revision serve-path

Webchat inbound events moved off the legacy serve path onto the env/revision
path. The new path did not honour three contract assumptions the **compiled
packs** depend on. All three live in the **greentic-runner flow engine**:

| Symptom | Broken assumption |
|---|---|
| Blank webchat / "flow type messaging is ambiguous" | entry-flow resolution (entry vs. `internal` flows) |
| Card rendered twice | single-emit finalization (`finalize_with` re-appended the terminal emit) |
| Button click returns the welcome card | `in.input.*` entry shape (routing context lacked `input` alias) |

### Migration 2 — the env-store secrets move (`greentic-setup #226` / `greentic-start #423`)

Secrets moved to the shared env store
(`~/.greentic/environments/<env>/.greentic/dev/.dev.secrets.env`), but the
orchestration around it stayed inconsistent, so the writer and reader disagreed
on **where** and **under which env** secrets live:

- gtc forced the runtime reader to the bundle root (a `GREENTIC_DEV_SECRETS_PATH` override)
- gtc `setup`/`provider`/`op` did not pin `GREENTIC_ENV`, so the writer wrote under one env and the reader looked under another
- the runtime reader (`open_dev_store_manager`) was never wired to the env store path helper

## The fix — two changesets

### Changeset A — restore the pack contract on the env-path (greentic-runner)

Already implemented and tested (PR #611):

1. entry-flow-aware routing (`entry_flow_by_type`, `tags_indicate_entry`)
2. finalize dedup (skip re-appending when `emitted.last()` is already the terminal payload)
3. `alias_input_to_entry` applied in `template_context` + `build_routing_context`

### Changeset B — finish the env-store secrets move (gtc + greentic-start)

1. gtc: drop the `GREENTIC_DEV_SECRETS_PATH` bundle-root override
2. gtc: pin `GREENTIC_ENV` on secret-touching child spawns (`setup`/`provider`/`op`/`wizard`) via `pinned_env_for_children` + `resolve_env_id`
3. greentic-start: wire `open_dev_store_manager` to `dev_store_path::find_existing` so the reader uses the same env store the writer used

### Explicitly dropped — `conv_dedup` rebuild

The single-flight `conv_dedup` rewrite targets a browser React-double-invoke
edge case, **not** the double you actually saw (that was Changeset A #2). It is
separate hardening and is **not** part of this fix.

## What this fix does NOT do — the weather card itself

Even with A + B perfect, the forecast will not render unless:

- a **valid WeatherAPI key** is provisioned (the placeholder 401s), and
- ideally the **weatherapi-pack** flow gains an `err_map` so a failed fetch
  renders an **error card** instead of falling through to the webchat
  "universal payload" fallback.

`flow_get_weather` today is `call_weather -> render`, with **no `err_map`**. On a
401 the render node tries to build the *success* card from missing data and
produces no `renderedCard`, so the reply classifier (which only recognises
`renderedCard`) emits the generic "universal payload". That is a demo-pack
concern (this repo), not a runtime bug.

## Regression tests — make a future migration break the build, not the demo

The real defect is process: **nothing exercised the two contracts end-to-end**,
so both migrations shipped green and broke silently in the browser. The fix is
two hermetic, isolated happy-path tests — one per migration — that mock every
external system. If either contract regresses again, `cargo test` (and CI) fails
early instead of a human noticing a blank webchat.

### T1 — `setup` secret round-trip (Changeset B contract)

Proves the **writer and reader agree on path + env**.

- **Isolate:** point the greentic home root at a tempdir; `GREENTIC_ENV=local`.
- **Act:** run the setup writer to store `weatherapi_pack/auth_param_get_weather_key`.
- **Assert:** the runtime reader (`open_dev_store_manager`, same env) reads the
  value back — i.e., the file lands in the shared env store and the reader looks
  there. Fails the moment writer/reader paths diverge again.
- **Mocks:** none external — filesystem only (tempdir home). No network, no prompts.
- **Home:** greentic-start (`dev_store_path` + `secrets_gate`), where both writer
  helpers and the reader live.

### T2 — `start` webchat happy-path (Changeset A contract)

Proves **entry-flow routing + single reply + `in.input` on button submit**.

- **Isolate:** load a fixture pack — an entry `welcome` flow + one `operation`
  flow — with the weather component replaced by a deterministic **stub** (no HTTP,
  no key).
- **Act 1:** POST a webchat message activity → assert **exactly one** reply and it
  carries a `renderedCard` (entry-flow routing + no double-emit).
- **Act 2:** POST an `Action.Submit` whose `value.operation` selects the operation
  flow → assert it routes there and `in.input.metadata.operation` is populated
  (i.e., it is NOT the welcome card again).
- **Mocks:** the external weather component is a stub → no API key / network.
- **Home:** greentic-start serve-path integration (or runner host), so it covers
  the whole `start` inbound→reply path, not just engine units.

**Reality check (from a scaffolding audit):** Changeset A's three contract seams
are *already* unit-tested in PR #611 — `entry_flow_by_type` (routing),
`finalize`'s no-double-emit, and `alias_input_to_entry` (button `in.input`
metadata) — plus `messaging_app::parse_envelopes` (renderedCard → adaptive card).
So the individual broken contracts are covered. What is NOT covered is the
**full serve-path round-trip**, and that is genuinely heavy: `run_app_flow`
executes the real wasmtime runner and there is **no in-process stub-component
seam** (`packs: Vec<Arc<PackRuntime>>` is concrete). A true POST→reply e2e
therefore needs a real WASM component fixture pack — a larger follow-up, not a
quick unit test. T2 is deferred as that WASM-fixture e2e; the contract-level
guards already stand.

Both T1 and the existing contract tests are plain `cargo test` targets so they
gate every PR.

## Status

- [x] Changeset A — done, tested (PR #611); its 3 contract seams are unit-covered
- [x] Changeset B — done (greentic-start branch `test/webchat-full-local`; gtc on
      `fix/gtc-secrets-env-pin` off main, compiles, v1.1.9)
- [x] conv_dedup — dropped (recoverable at `818a091` if ever needed)
- [x] **T1 — setup env-store rendezvous test** — implemented + passing, shipped
      with the changeset-B secrets commit
- [ ] **T2 — full serve-path webchat e2e** — deferred; needs a WASM component
      fixture pack (contract seams already unit-covered)
- [ ] weather-pack `err_map` + valid key — demo-side follow-up
