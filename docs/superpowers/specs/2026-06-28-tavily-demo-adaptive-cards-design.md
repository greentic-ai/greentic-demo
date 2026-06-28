# Tavily Agentic Demo + Adaptive Cards — Design

**Date:** 2026-06-28
**Status:** Approved (design); pending implementation plan
**Scope:** Modify the existing `crates/agentic-research-tavily-demo` so the bot greets
users with an Adaptive Card and renders each research answer as an Adaptive Card,
instead of replying in plain text.

## Goal

Show the platform's two headline capabilities together in one demo: an Agentic
Worker (`dw.agent`) that researches with Tavily, **and** Adaptive Card rendering
(`component-adaptive-card`). The agent's research answer is presented as a card;
the conversation opens with a welcome card.

## Decisions (locked during brainstorming)

1. **Modify the existing demo**, not a new crate. The plain-text Tavily demo
   becomes the card-rich version. One demo, richer UI.
2. **Sources as inline markdown links.** The agent already cites source URLs in
   its text reply (system prompt). The answer card renders that markdown reply in
   a `wrap`-ed `TextBlock` — no structured JSON output from the LLM (robust, no
   fragile parsing).
3. **Welcome card triggered on the first message of a session** (a `greeted`
   state flag), not on connect. Webchat exposes no proactive "conversation start"
   event, so a true on-open greeting would need provider work — out of scope. The
   welcome card therefore precedes the first answer.

## Architecture

The demo stays a single `application` pack with one messaging flow. Two things are
added: the `component-adaptive-card` WASM component (OCI-resolved, as other card
demos declare it) and two card assets. The `dw.agent` + Tavily tool extension
(`store://greentic.tavily`) and the auto-derived credential setup are unchanged.

### Files

- **New** `assets/cards/welcome.json` — welcome Adaptive Card: a title
  ("Agentic Research Assistant"), one intro `TextBlock`, and **three example
  question buttons** (`Action.Submit`). Each button submits a preset query string
  (e.g. "What's new in AI this week?") so a click drives the agent like a typed
  message.
- **New** `assets/cards/research_answer.json` — answer Adaptive Card: a small
  header `TextBlock` plus a `TextBlock` with `text: "${answer}"`, `wrap: true`.
  The `${answer}` field binds to the agent's reply (Adaptive Card Templating, the
  same `${...}` binding `deep-research-demo` already uses).
- **Modified** `flows/on_message.ygtc` — rewired (below).
- **Modified** `build-answer.json` `pack_overlay` — updated `pack.yaml` (adds the
  `component-adaptive-card` component) and the rewired flow. `pack.extensions.json`
  (Tavily store source) is unchanged.

### Flow (`flows/on_message.ygtc`)

Per inbound message:

1. **`greet_or_answer`** — branch on session state `greeted`.
   - If unset: render `welcome.json` via `component-adaptive-card` and emit it,
     set `greeted = true`, then continue to the agent.
   - If set: go straight to the agent.
2. **`assistant`** — `dw.agent` (operation `demo_assistant`) with
   `user_text: "{{in.input.text}}"`. Returns `reply` (markdown text with inline
   source links).
3. **`render_answer`** — `component-adaptive-card`, operation `render`,
   `card_source: asset`, `card_spec.asset_path: cards/research_answer.json`,
   `card_spec.template_params: { answer: "{{node.assistant.reply}}" }`. Returns
   `rendered_card`.
4. **`send_card`** — `emit.response` with
   `renderedCard: "{{node.render_answer.rendered_card}}"`.

### Data flow

```
inbound message
  → (first message only) welcome card emitted, greeted=true
  → dw.agent (Tavily web search) → reply (markdown + source links)
  → component-adaptive-card render: bind reply into research_answer.json ${answer}
  → emit.response renderedCard
```

## Error handling

- **Card render failure:** `validation_mode: warn` (non-fatal). If the render
  node fails or returns no card, the flow falls back to emitting the agent's
  `reply` as a plain `text` message so the user still gets the answer.
- **Agent failure** (guardrail-denied, timeout, LLM error): emit a short fallback
  `text` message; do not attempt to render a card from an empty reply.

## What stays the same (must not regress)

- **Auto-derived credential setup.** `component-adaptive-card` declares no
  `secret_requirements`, so the generated `assets/setup.yaml` /
  `secret-requirements.json` stay exactly the DeepSeek + Tavily form. The
  generator merges component requirements (empty here). This is asserted in
  testing.
- **`pack.extensions.json`** Tavily store source and the
  `GREENTIC_STORE_URL` defaulting in `package_demos.sh`.

## Testing

- Rebuild via `package_demos.sh agentic-research-tavily-demo` (fixed greentic-pack
  on PATH, `GREENTIC_STORE_URL` set).
- Assert the produced `demos/agentic-research-tavily-demo.gtpack` contains both
  card assets, the `component-adaptive-card` component, **and** the unchanged
  auto-derived `assets/setup.yaml` (DeepSeek + Tavily questions).
- Manual smoke over webchat: first message shows the welcome card; a question
  returns a research answer rendered as a card with working source links; example
  buttons drive the agent.

## Open items to resolve during planning

These design-level mechanics need their exact syntax confirmed against the
codebase when the plan is written (each has a known precedent to copy):

1. Exact static-`.ygtc` syntax for a `component-adaptive-card` render node and for
   reading/writing/branching on the `greeted` session-state flag (precedents:
   `component-adaptive-card/flows/*.ygtc`, `telco-x-demo` card emit, the
   `greentic-state` working-memory nodes).
2. Exact `pack.yaml` `components:` entry + OCI reference for
   `component-adaptive-card` (precedent: existing card demos' packs).
3. Confirm `emit.response` accepts `renderedCard` from a generic
   adaptive-card node output (precedent: `telco-x-demo` `renderedCard`).
