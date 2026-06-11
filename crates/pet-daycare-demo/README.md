# pet-daycare-demo

Greentic chatbot demo for a pet daycare front desk. The point of this
demo is to **showcase Fast2Flow intent routing + prefill** on a
realistic workflow surface — check-in, check-out, attendance, notes,
new pet registration, boarding, vaccinations.

## What's in the box

```text
crates/pet-daycare-demo/
├── assets/
│   ├── cards/              ← Adaptive Card templates with ${prefill_*}
│   │   ├── welcome_card.json
│   │   ├── checkin_card.json
│   │   ├── checkout_card.json
│   │   ├── attendance_card.json
│   │   ├── note_card.json
│   │   ├── register_pet_card.json
│   │   ├── boarding_card.json
│   │   └── vaccinations_card.json
│   └── intent-index.json   ← Fast2Flow IndexManifestV2 (7 intents)
├── external-components/    ← MCP wasm generated from petstore openapi
│   └── petstore.component.wasm
├── openapi/
│   └── petstore.yaml       ← source spec fed to greentic-mcp-gen
└── src/lib.rs              ← stub
```

## Rebuilding the petstore component

```bash
cd crates/pet-daycare-demo
greentic-mcp-gen \
  --spec $(pwd)/openapi/petstore.yaml \
  --output-dir $(pwd)/external-components
```

Output: `external-components/petstore.component.wasm`. The
`build-answer.json` references it via
`pack_overlay.external_components` so `gtc wizard apply` bundles it
into the pack at `components/petstore.component.wasm`.

## The seven intents

| Intent flow | Card | Sample utterance |
| --- | --- | --- |
| `intent-checkin` | `checkin_card` | "Check in Bella for today at 9am" |
| `intent-checkout` | `checkout_card` | "Rex is going home now" |
| `intent-attendance` | `attendance_card` | "Who's here today?" |
| `intent-note` | `note_card` | "Add a note for Max: didn't eat lunch" |
| `intent-register` | `register_pet_card` | "Register a new dog called Cooper" |
| `intent-boarding` | `boarding_card` | "Book Bella for boarding next Friday to Sunday" |
| `intent-vaccinations` | `vaccinations_card` | "When does Luna's rabies expire?" |

## Prefill convention

Every form card opts into the generic `${prefill_<kind>}` substitution
the runtime emits from intent-extracted entities. Concretely:

| Card field | Placeholder | Filled from |
| --- | --- | --- |
| Date inputs | `${prefill_date_iso}` | `date` entity, ISO form (e.g. `2026-06-04`) |
| Time inputs | `${prefill_time}` | `time` entity (e.g. `14:00`) |
| Pet name | `${prefill_person}` | `person` entity (the chatter's named pet) |
| Owner phone | `${prefill_phone}` | `phone` entity (when feature is enabled) |
| Owner email | `${prefill_email}` | `email` entity (when feature is enabled) |

If no entity is extracted for a key, the runtime injects an empty
string default so the placeholder text never renders.

## How it runs end-to-end

1. User types into Webchat → message lands in greentic-start.
2. Pack carries the `greentic.cap.fast2flow.v1` capability; the gate
   fires and invokes the routing host.
3. Routing host runs `greentic-intent` over the text → marked_text +
   entities (date, time, person, ...).
4. BM25 over the marked text + tags + utterances in
   `assets/intent-index.json` → top candidate.
5. Routing host returns `Dispatch { target, entities }`.
6. greentic-start sets `routeToCardId` to the dispatch target's node,
   surfaces every entity as a `prefill_*` envelope metadata key.
7. Card asset is read from the pack, `${prefill_*}` placeholders
   resolve, card renders.

## Author this pack into a bundle

```bash
# From the greentic-demo repo root:
gtc wizard apply --answers crates/pet-daycare-demo/build-answer.json --yes --non-interactive
```

(build-answer.json forthcoming — see follow-up step.)
