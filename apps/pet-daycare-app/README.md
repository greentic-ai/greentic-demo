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

## Run

```bash
greentic-start start --bundle ../pet-daycare-demo-bundle
```

The pack opts into fast2flow at the manifest level by declaring
`greentic.cap.fast2flow.v1` in `pack.yaml`, and the runtime's
pack-fallback materializer picks up `assets/intent-index.json` automatically
— no env vars required for a default local run.

### Optional tuning

| Variable | Default | Why you'd touch it |
| --- | --- | --- |
| `FAST2FLOW_MIN_CONFIDENCE` | `0.5` | The default works for longer marker-templated utterances. For the short utterances in this demo's `intent-index.json`, set `0.05` to relax the BM25 threshold and let `"who is here today"` style messages dispatch. |
| `GREENTIC_FAST2FLOW_INDEXES_PATH` | `<temp_dir>/greentic-fast2flow-indexes` | Override when a k8s/cloud deployer wants a durable path. Local runs don't need this. |

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

- The default `min_confidence` (0.5) is too strict for the marker-free
  utterances we ship — `FAST2FLOW_MIN_CONFIDENCE=0.05` is recommended for
  this demo until the index entries are tuned.
- Fast2flow dispatch produces `routeToCardId` only; it does not inject
  `operation` metadata. So an utterance match renders the static card without
  invoking the underlying flow's wasm. The button-driven path is the only one
  that hits the petstore API end-to-end today.
