# Env-path parity — feature checklist & test validation

Companion to `PLAN-webchat-env-migration-holistic-fix.md`. Completes the env/
revision migration (B4b #251 + A.2–A.5) to behavioral parity with the legacy
`messaging_app::run_app_flow`, implemented natively (env store + revisions).

**Rule:** a feature is "done" only when it has (a) an implementation, (b) a unit
test pinning its contract, and (c) a passing stage in the single **e2e journey
test**. External input (inbound activities, WeatherAPI HTTP) is mocked — no
browser, no network, no real key.

---

## Features

### F1 — Multi-provider entry-flow routing  ✅ DONE
Provider-ingress resolves to the **app** flow; messaging-provider-pack flows are
excluded from type-only routing.
- [x] Impl — `entry_flow_by_type` skips `messaging.*` provider packs (greentic-runner `5d5b8f5…`)
- [x] Unit test — `entry_flow_by_type_excludes_messaging_provider_pack_flows`
- [x] Unit test (preserved) — `entry_flow_by_type_still_ambiguous_across_two_entrypoints`
- [ ] E2E stage 1 — first contact resolves to the app flow (no "ambiguous")

### F2 — Config injection from the env store
Pack's applied setup config reaches the flow's entry metadata (legacy read
`setup-answers.json`; env path must read the **env store**).
- [ ] Impl — inject applied config at `dispatch_activity` from the env store, not the bundle file
- [ ] Unit test — configured keys present in the flow entry metadata for a revision
- [ ] E2E stage 3 — a config-dependent card field renders

### F3 — Secret read-scope alignment  (OPEN #3)
`secrets_store::get` resolves at the **deployment's runtime `env/tenant/team`**
(setup wrote tenant `demo`; component read `default` → WeatherAPI 1002).
- [ ] Impl — align the component secret read scope to the deployment runtime scope
- [ ] Unit test — a secret written under the deployment tenant is read back by the component's scope (the 1002-vs-2006 discriminator)
- [ ] E2E stage 4 — weather action with a mocked 200 renders the forecast card (not the `service_auth`/1002 error)

### F4 — `routeToCardId` + resume for multi-turn card flows
Button turn **resumes** the paused flow and selects the routed card instead of
re-running fresh to the welcome card.
- [ ] Impl — env-path session/resume key matches the render-and-pause turn and the button turn
- [ ] Unit test — a paused flow resumes on the next activity and honors `routeToCardId`/`nextCardId`
- [ ] E2E stage 2 — button submit `{routeToCardId: X}` yields card X, not welcome

### F0 — DIAG (temporary, diagnostic)
- [ ] `dispatch_activity` logs resolved `(pack_id, flow_id)` + entry metadata keys (removed once F2–F4 land)

---

## The e2e journey test (the whole journey, one test)

**What it drives:** the env-path executor (`RunnerHost::handle_activity_for_revision`
against a fixture revision — or the full server via `ws_test_support`), i.e. the
real path, not `run_app_flow`.

**Mocks (external input only):**
- Inbound activities — synthesized DirectLine/webchat requests: conversation-create, button submit, secret-backed action. No browser.
- WeatherAPI HTTP — runner HTTP mock returns a canned 200 forecast. No network, no real key.
- Secrets — seeded in the env store at the deployment's runtime `env/tenant/team`.

**Journey & assertions (each stage guards one feature):**
| Stage | Input | Assert | Guards |
|---|---|---|---|
| 1 | POST `/v3/directline/conversations` | reply carries the **welcome** card, resolved to the app flow | F1 |
| 2 | button submit `{routeToCardId: "about"}` | reply carries the **about** card (resumed), NOT welcome | F4 |
| 3 | a config-dependent card | rendered card contains the injected config value | F2 |
| 4 | weather action (secret-backed) + mocked WeatherAPI 200 | reply carries the **forecast** card, NOT `service_auth`/1002 | F3, F2 |

**Guard property:** every stage asserts a specific rendered card id/content, so a
regression in any parity feature fails the build — not a human noticing a blank
webchat.

---

## Status rollup
- [x] F1 — implemented + unit-tested
- [ ] F2 — config injection (env store)
- [ ] F3 — secret read-scope (OPEN #3)
- [ ] F4 — routeToCardId + resume
- [ ] F0 — DIAG (in-flight; temporary)
- [ ] **E2E journey test** — built incrementally; green only when F1–F4 all pass
