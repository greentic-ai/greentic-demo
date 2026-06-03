# pet-daycare-app

Demo pack showcasing fast2flow intent routing + a live WASM tool call to the
public Swagger petstore API (`find_pets_by_status`).

## Build

```bash
greentic-pack resolve --in apps/pet-daycare-app
greentic-pack build   --in apps/pet-daycare-app
```

Output: `apps/pet-daycare-app/dist/pet-daycare-app.gtpack`. Copy it into a
bundle's `packs/` directory as `pet-daycare-pack.gtpack`.

## Pet daycare bundle env vars

The fast2flow gate currently needs two env vars at bundle startup; until the
pack-level capability declaration (`greentic.cap.fast2flow.v1`) is wired
through `greentic-pack`'s `pack.yaml` schema, the gate must be opened via env:

| Variable | Value | Why |
| --- | --- | --- |
| `GREENTIC_FAST2FLOW_INDEXES_PATH` | any writable dir | Sets `deploy_intent=true`; the pack-fallback materializer writes `assets/intent-index.json` into `<scope>/index.json` here. |
| `GREENTIC_FAST2FLOW_FORCE_ENABLE` | `1` | Stand-in for `BundleCapabilityGate` until pack.yaml carries the opt-in. |
| `FAST2FLOW_MIN_CONFIDENCE` | `0.05` | The 0.5 default is tuned for longer marker-templated utterances; for the short utterances in `intent-index.json` we need to lower the bar. |

Example:

```bash
GREENTIC_FAST2FLOW_INDEXES_PATH=/tmp/fast2flow-indexes \
GREENTIC_FAST2FLOW_FORCE_ENABLE=1 \
FAST2FLOW_MIN_CONFIDENCE=0.05 \
greentic-start start --bundle ../pet-daycare-demo-bundle --tenant demo --team default
```

## What works end-to-end

- Welcome card renders on conversation start.
- "Today's Attendance" button (and the attendance card's "Refresh" button)
  carry `operation: list_pets` in `Action.Submit.data`. The `default` flow's
  `flow.call` dispatcher routes that to `flow_list_pets`, which:
  1. invokes the `petstore` wasm's `find_pets_by_status` operation against the
     live Swagger petstore, and
  2. renders `assets/cards/attendance_card.json` with the response bound into
     `${result.0.name}` etc. (Currently shows the first 5 pets — the
     adaptive-card component does not implement ACT `$data` iteration, so the
     card uses indexed paths with `||` defaults.)
- Natural language ("who is here today", "check in Bella for today at 9am", …)
  hits the fast2flow BM25 index and dispatches to the matching card via
  `routeToCardId`. This is the asset-rendering shortcut — it does not invoke
  the petstore wasm. Driving the API call from the intent currently still
  requires the button.

## Known gaps

- `greentic-pack` doesn't yet honour `capabilities:` in `pack.yaml`, so we open
  the fast2flow gate via env vars above. Once supported, declaring
  `greentic.cap.fast2flow.v1` at the pack level should remove the need for
  `GREENTIC_FAST2FLOW_FORCE_ENABLE`.
- The default `min_confidence` (0.5) is too strict for the marker-free
  utterances we ship — `FAST2FLOW_MIN_CONFIDENCE=0.05` is the demo override.
- Fast2flow dispatch produces `routeToCardId` only; it does not inject
  `operation` metadata. So an utterance match renders the static card without
  invoking the underlying flow's wasm. The button-driven path is the only one
  that hits the petstore API end-to-end today.
