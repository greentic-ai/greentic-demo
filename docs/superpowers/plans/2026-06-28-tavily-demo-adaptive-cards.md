# Tavily Agentic Demo + Adaptive Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `crates/agentic-research-tavily-demo` greet users with an Adaptive Card and render each research answer as an Adaptive Card, instead of plain text.

**Architecture:** The demo stays one `application` pack with one messaging flow. We vendor the `component-adaptive-card` WASM into the crate, add two card assets, and rewire the static `on_message.ygtc` (in the `build-answer.json` overlay) to: branch on a `greeted` session-state flag → emit a welcome card on the first message → run `dw.agent` (Tavily) → render the agent reply into an answer card. The Tavily tool extension and the auto-derived credential setup are untouched.

**Tech Stack:** Greentic static `.ygtc` flows, Adaptive Card Templating (`${...}` binding), `ai.greentic.component-adaptive-card` WASM, `greentic-state` (`state.get`/`state.set`), `greentic-pack` build via `scripts/package_demos.sh`.

## Global Constraints

- Modify the EXISTING crate `crates/agentic-research-tavily-demo`; do not create a new crate.
- **The auto-derived credential setup must NOT regress.** Do NOT add `crates/agentic-research-tavily-demo/assets/setup.yaml` or `assets/secret-requirements.json`. `component-adaptive-card` declares no `secret_requirements`, so the generated form must stay exactly the DeepSeek + Tavily questions.
- `pack.extensions.json` (Tavily `store://greentic.tavily@1.2.4-research`, `allow_tags:true`) is unchanged.
- Welcome card triggers on the FIRST message of a session via a `greeted` state flag; sources render as inline markdown links inside the answer card's `${answer}` TextBlock (no structured LLM JSON).
- Rebuild always uses the generator-equipped `greentic-pack` (research, `06cc1f2`+) on PATH and `GREENTIC_STORE_URL=https://store.greentic.cloud` (already defaulted in `package_demos.sh`).
- Commits use conventional format. Do NOT add Claude co-author attribution.
- Card-node + state syntax precedents (copy from these): `greentic-demo/apps/pet-daycare-app/flows/flow_list_pets.ygtc` (`card:` node), `msg-event-demo/packs/greentic-finance/flows/transfer.ygtc` (emit-then-`to:` continuation, `condition:` routing), `msg-event-demo/packs/control-chain-pack/flows/fallback.ygtc` (`state.get`/`state.set`).

---

### Task 1: Vendor the adaptive-card component into the crate

**Files:**
- Create: `crates/agentic-research-tavily-demo/components/adaptive-card/component_adaptive_card.wasm`
- Create: `crates/agentic-research-tavily-demo/components/adaptive-card/component.manifest.json`
- Source to copy from: `apps/pet-daycare-app/components/adaptive-card/` (same repo, proven in pet-daycare-app)

**Interfaces:**
- Produces: a local WASM component at the path `components/adaptive-card/component_adaptive_card.wasm`, referenced by `pack.yaml` in Task 3 as `wasm: components/adaptive-card/component_adaptive_card.wasm`. `package_demos.sh` copies `crate/components/` into the built pack (loop-2 lines ~519-527) and `sync_adaptive_card_component_version` (lines ~130-140) patches its declared version.

- [ ] **Step 1: Copy the component artifacts**

```bash
cd /Users/bimapangestu/Desktop/Works/personal/greentic/greentic-demo
mkdir -p crates/agentic-research-tavily-demo/components/adaptive-card
cp apps/pet-daycare-app/components/adaptive-card/component_adaptive_card.wasm \
   crates/agentic-research-tavily-demo/components/adaptive-card/
cp apps/pet-daycare-app/components/adaptive-card/component.manifest.json \
   crates/agentic-research-tavily-demo/components/adaptive-card/
```

- [ ] **Step 2: Verify the WASM is present and is a real component (magic bytes `\0asm`)**

Run:
```bash
cd /Users/bimapangestu/Desktop/Works/personal/greentic/greentic-demo
ls -la crates/agentic-research-tavily-demo/components/adaptive-card/
xxd -l 4 crates/agentic-research-tavily-demo/components/adaptive-card/component_adaptive_card.wasm
jq -e '.operations? // .schema? // .' crates/agentic-research-tavily-demo/components/adaptive-card/component.manifest.json >/dev/null && echo MANIFEST_OK
```
Expected: the `.wasm` is ~5 MB, `xxd` shows `0061 736d` (`\0asm`), and `MANIFEST_OK` prints.

- [ ] **Step 3: Commit**

```bash
cd /Users/bimapangestu/Desktop/Works/personal/greentic/greentic-demo
git add crates/agentic-research-tavily-demo/components/adaptive-card/
git commit -m "feat(agentic-research-tavily-demo): vendor adaptive-card component wasm"
```

---

### Task 2: Author the two Adaptive Card assets

**Files:**
- Create: `crates/agentic-research-tavily-demo/assets/cards/welcome.json`
- Create: `crates/agentic-research-tavily-demo/assets/cards/research_answer.json`

**Interfaces:**
- Produces: `assets/cards/welcome.json` (no data binding) and `assets/cards/research_answer.json` (binds `${answer}`). Task 3's flow loads them by `asset_path: assets/cards/<name>.json`; `research_answer.json` receives `payload: { answer: <agent reply> }`. `package_demos.sh` copies `crate/assets/` into the built pack (loop-2 lines ~519-521), so these ship in the `.gtpack`.
- NOTE: do NOT place a `setup.yaml` under `assets/` — only `assets/cards/`. A `setup.yaml` would shadow the auto-generator (see Global Constraints).

- [ ] **Step 1: Write `welcome.json` (informational welcome card)**

```bash
cd /Users/bimapangestu/Desktop/Works/personal/greentic/greentic-demo
mkdir -p crates/agentic-research-tavily-demo/assets/cards
cat > crates/agentic-research-tavily-demo/assets/cards/welcome.json <<'JSON'
{
  "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
  "type": "AdaptiveCard",
  "version": "1.6",
  "speak": "Welcome to the Agentic Research Assistant. Ask any question and I will research the live web and answer with sources.",
  "body": [
    {
      "type": "TextBlock",
      "text": "Agentic Research Assistant",
      "weight": "Bolder",
      "size": "ExtraLarge",
      "color": "Accent",
      "wrap": true
    },
    {
      "type": "TextBlock",
      "text": "Ask me anything. I research the live web with Tavily and answer concisely, with source links.",
      "wrap": true,
      "isSubtle": true,
      "spacing": "Small"
    },
    {
      "type": "TextBlock",
      "text": "Try asking:",
      "weight": "Bolder",
      "spacing": "Medium",
      "wrap": true
    },
    {
      "type": "TextBlock",
      "text": "- What's new in AI this week?\n- What is the latest price of Bitcoin?\n- Who won the most recent Formula 1 race?",
      "wrap": true
    }
  ]
}
JSON
```

> **Note (deviation from spec, intentional):** the spec described three `Action.Submit` example-question *buttons*. The delivery path from an Adaptive Card `Action.Submit` `data` payload back into `dw.agent`'s `user_text` over webchat is unverified, so this plan renders the example questions as text to keep the demo robust (matching the user's "robust over fragile" choice for sources). Interactive buttons can be a follow-up once the submit→agent-input mapping is confirmed.

- [ ] **Step 2: Write `research_answer.json` (binds the agent reply)**

```bash
cd /Users/bimapangestu/Desktop/Works/personal/greentic/greentic-demo
cat > crates/agentic-research-tavily-demo/assets/cards/research_answer.json <<'JSON'
{
  "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
  "type": "AdaptiveCard",
  "version": "1.6",
  "body": [
    {
      "type": "TextBlock",
      "text": "Research result",
      "weight": "Bolder",
      "size": "Large",
      "color": "Accent",
      "wrap": true
    },
    {
      "type": "TextBlock",
      "text": "${answer}",
      "wrap": true
    }
  ]
}
JSON
```

- [ ] **Step 3: Verify both cards are valid JSON with the expected binding**

Run:
```bash
cd /Users/bimapangestu/Desktop/Works/personal/greentic/greentic-demo
jq -e '.type=="AdaptiveCard"' crates/agentic-research-tavily-demo/assets/cards/welcome.json >/dev/null && echo WELCOME_OK
jq -e '[.body[].text] | index("${answer}")' crates/agentic-research-tavily-demo/assets/cards/research_answer.json >/dev/null && echo ANSWER_BINDS
```
Expected: `WELCOME_OK` and `ANSWER_BINDS` both print.

- [ ] **Step 4: Commit**

```bash
cd /Users/bimapangestu/Desktop/Works/personal/greentic/greentic-demo
git add crates/agentic-research-tavily-demo/assets/cards/
git commit -m "feat(agentic-research-tavily-demo): add welcome + research-answer adaptive cards"
```

---

### Task 3: Rewire the pack.yaml + flow in build-answer.json

**Files:**
- Modify: `crates/agentic-research-tavily-demo/build-answer.json` (the `pack_overlay.files` entries for `pack.yaml` and `flows/on_message.ygtc`)

**Interfaces:**
- Consumes: the component from Task 1 (`components/adaptive-card/component_adaptive_card.wasm`) and the cards from Task 2 (`assets/cards/{welcome,research_answer}.json`).
- Produces: a `pack.yaml` that declares the `ai.greentic.component-adaptive-card` component (keeping the existing `demo_assistant` agent + Tavily tools), and an `on_message.ygtc` whose nodes are `check_greeted` (start) → `send_welcome` → `mark_greeted` → `assistant` → `render_answer`.

- [ ] **Step 1: Replace the `pack.yaml` overlay content (add the component block)**

Use this exact `jq` to set the `pack.yaml` overlay file's `content` (keeps everything else — agents, dependencies, flows — identical, only flips `components: []` to the adaptive-card component):

```bash
cd /Users/bimapangestu/Desktop/Works/personal/greentic/greentic-demo
BA=crates/agentic-research-tavily-demo/build-answer.json
PACKYAML='pack_id: agentic-research-tavily-demo
version: 0.1.0
kind: application
publisher: Greentic
components:
- id: ai.greentic.component-adaptive-card
  version: 0.1.0
  world: greentic:component/component@0.6.0
  supports:
  - messaging
  profiles:
    default: stateless
    supported:
    - stateless
  capabilities:
    wasi:
      random: true
      clocks: true
    host: {}
  wasm: components/adaptive-card/component_adaptive_card.wasm
dependencies: []
flows:
- id: on_message
  file: flows/on_message.ygtc
  tags:
  - default
  entrypoints:
  - default
agents:
  demo_assistant:
    agent_id: demo_assistant
    system_prompt: "You are a web research assistant running as an Agentic Worker inside a Greentic flow. When the user asks about facts, recent events, prices, people, products, or anything you are not certain of, call the tavily_search tool to find current information online, then answer concisely in the user'"'"'s language and cite the source URLs as markdown links. Use tavily_extract for the full content of a specific URL. Do not fabricate facts or sources."
    tools:
      - extension_id: greentic.tavily
        tool_name: tavily_search
      - extension_id: greentic.tavily
        tool_name: tavily_extract
    guardrails: []
    llm:
      provider: deepseek
      model: deepseek-chat
      credential_ref: deepseek
    limits:
      max_iter: 6
      timeout: 120
'
jq --arg c "$PACKYAML" '(.pack_overlay.files[] | select(.path=="pack.yaml") | .content) = $c' "$BA" > "$BA.tmp" && mv "$BA.tmp" "$BA"
```

- [ ] **Step 2: Replace the `flows/on_message.ygtc` overlay content (the new multi-node flow)**

```bash
cd /Users/bimapangestu/Desktop/Works/personal/greentic/greentic-demo
BA=crates/agentic-research-tavily-demo/build-answer.json
FLOW='id: default
title: Agentic Worker Demo - Message Handler
description: Greet with a card, research each message with an Agentic Worker (dw.agent), reply with an Adaptive Card
type: messaging
start: check_greeted

nodes:
  # Branch on a session flag so the welcome card is shown only on the first message.
  check_greeted:
    state.get:
      key: greeted
    routing:
      - condition: "{{prev.value}}"
        to: assistant
      - to: send_welcome

  # First message only: emit the welcome card, then continue to the agent.
  send_welcome:
    card:
      input:
        card_source: asset
        card_spec:
          asset_path: assets/cards/welcome.json
        mode: renderAndValidate
    routing:
      - to: mark_greeted

  mark_greeted:
    state.set:
      key: greeted
      value: true
    routing:
      - to: assistant

  # The Agentic Worker researches the user message with Tavily and returns `reply`.
  assistant:
    dw.agent:
      user_text: "{{in.input.text}}"
    operation: demo_assistant
    routing:
      - to: render_answer

  # Render the agent reply (markdown + source links) into the answer card.
  render_answer:
    card:
      input:
        card_source: asset
        card_spec:
          asset_path: assets/cards/research_answer.json
        payload:
          answer: "{{node.assistant.reply}}"
        mode: renderAndValidate
    routing:
      - out: true
'
jq --arg c "$FLOW" '(.pack_overlay.files[] | select(.path=="flows/on_message.ygtc") | .content) = $c' "$BA" > "$BA.tmp" && mv "$BA.tmp" "$BA"
```

- [ ] **Step 3: Verify the overlay is valid + carries the new pack.yaml + flow**

Run:
```bash
cd /Users/bimapangestu/Desktop/Works/personal/greentic/greentic-demo
BA=crates/agentic-research-tavily-demo/build-answer.json
jq -e '.' "$BA" >/dev/null && echo JSON_OK
jq -r '.pack_overlay.files[] | select(.path=="pack.yaml") | .content' "$BA" | grep -q 'ai.greentic.component-adaptive-card' && echo PACK_HAS_COMPONENT
jq -r '.pack_overlay.files[] | select(.path=="flows/on_message.ygtc") | .content' "$BA" | grep -q 'check_greeted' && echo FLOW_HAS_GREETED
jq -r '.pack_overlay.files[] | select(.path=="flows/on_message.ygtc") | .content' "$BA" | grep -q 'asset_path: assets/cards/research_answer.json' && echo FLOW_RENDERS_ANSWER
```
Expected: `JSON_OK`, `PACK_HAS_COMPONENT`, `FLOW_HAS_GREETED`, `FLOW_RENDERS_ANSWER` all print.

- [ ] **Step 4: Commit**

```bash
cd /Users/bimapangestu/Desktop/Works/personal/greentic/greentic-demo
git add crates/agentic-research-tavily-demo/build-answer.json
git commit -m "feat(agentic-research-tavily-demo): wire welcome + answer cards into the flow"
```

---

### Task 4: Rebuild the gtpack and assert contents (no regression)

**Files:**
- Modify (rebuilt artifact): `demos/agentic-research-tavily-demo.gtpack`

**Interfaces:**
- Consumes: Tasks 1-3. Produces the shipping `.gtpack` containing both cards, the adaptive-card component, and the UNCHANGED auto-derived `assets/setup.yaml` (DeepSeek + Tavily).

- [ ] **Step 1: Rebuild via the real pipeline with the fixed greentic-pack on PATH**

```bash
cd /Users/bimapangestu/Desktop/Works/personal/greentic/greentic-demo
FIXEDBIN=/Users/bimapangestu/Desktop/Works/personal/greentic/greentic-pack/target/debug
PATH="$FIXEDBIN:$PATH" GREENTIC_STORE_URL="https://store.greentic.cloud" \
  bash scripts/package_demos.sh agentic-research-tavily-demo 2>&1 | tail -8
```
Expected: prints `Created demos/agentic-research-tavily-demo.gtpack` (and the bundle line). If `greentic-pack` resolves the store ext and builds, no `Skipping` line appears for this demo.

- [ ] **Step 2: Assert the gtpack contains cards + component + the UNCHANGED auto-derived setup**

Run:
```bash
cd /Users/bimapangestu/Desktop/Works/personal/greentic/greentic-demo
GT=demos/agentic-research-tavily-demo.gtpack
unzip -l "$GT" | grep -E 'assets/cards/welcome.json|assets/cards/research_answer.json' && echo CARDS_IN_PACK
unzip -l "$GT" | grep -E 'adaptive_card.*\.wasm|components/' && echo COMPONENT_IN_PACK
# Auto-derived credential form must be byte-identical in shape (deepseek + api_key, no regression):
rm -rf /tmp/t8card && mkdir /tmp/t8card && (cd /tmp/t8card && unzip -o -q "$OLDPWD/$GT" assets/setup.yaml)
grep -q 'name: deepseek' /tmp/t8card/assets/setup.yaml && grep -q 'name: api_key' /tmp/t8card/assets/setup.yaml && grep -q 'title: Api Key' /tmp/t8card/assets/setup.yaml && echo SETUP_UNCHANGED
```
Expected: `CARDS_IN_PACK`, `COMPONENT_IN_PACK`, and `SETUP_UNCHANGED` all print. (`title: Api Key` confirms the merged title fix is in effect and the credential form did not regress.)

- [ ] **Step 3: Guard against committing secrets / local bundle dir**

Run:
```bash
cd /Users/bimapangestu/Desktop/Works/personal/greentic/greentic-demo
git status --short
git check-ignore agentic-research-tavily-demo-bundle/ && echo BUNDLE_IGNORED
```
Expected: `agentic-research-tavily-demo-bundle/` is ignored (`BUNDLE_IGNORED` prints); only `demos/agentic-research-tavily-demo.gtpack` shows as modified among tracked files.

- [ ] **Step 4: Commit the rebuilt gtpack**

```bash
cd /Users/bimapangestu/Desktop/Works/personal/greentic/greentic-demo
git add demos/agentic-research-tavily-demo.gtpack
git commit -m "feat(agentic-research-tavily-demo): rebuild gtpack with welcome + answer cards"
```

---

## Manual verification (after Task 4, not automated)

Smoke over webchat (run `gtc start` on the rebuilt bundle): the first message shows the welcome card; a research question returns an answer rendered as an Adaptive Card with the answer text and clickable source links; the second message answers without re-showing the welcome card (confirms the `greeted` flag).

## Deferred from spec: explicit text fallback

The spec's error-handling section ("on render failure fall back to plain text; on
agent failure emit fallback text") is intentionally NOT wired as failure-branch
routing in this plan. Detecting a render or agent failure and routing to a text
`emit.response` needs failure-output / error-branch `.ygtc` syntax that is not yet
verified against the installed `greentic-flow`, and is over-built for a demo. The
demo instead relies on the card node's `mode: renderAndValidate` with the
component's `validation_mode: warn` (non-fatal render) and the runtime's default
agent-error surfacing. Wiring an explicit text fallback is a follow-up once the
error-branch syntax is confirmed.

## Notes for the implementer

- If `package_demos.sh` prints `Skipping agentic-research-tavily-demo: pack build failed`, capture the underlying `greentic-pack build` error — the two likely causes are (a) the `card:` node syntax/`state.get`/`state.set` not matching the installed `greentic-flow` build, or (b) the store ext not resolving (check `GREENTIC_STORE_URL`). Use systematic-debugging; do not guess-patch.
- The `card:` node emits its rendered card AND continues via `to:` (proven in `msg-event-demo` finance flows where `emit.response` nodes route `to:` a next node). `out: true` ends the flow after emitting.
