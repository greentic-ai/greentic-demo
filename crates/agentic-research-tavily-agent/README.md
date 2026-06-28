# agentic-research-tavily-agent

A **standalone Agentic Worker pack** (`kind: dw-application`) for the Tavily web-research agent (`demo_assistant`): DeepSeek `deepseek-chat` reasoning + the `greentic.tavily` tool extension (`tavily_search` / `tavily_extract`).

Unlike an application pack, this pack carries no flows or messaging components — only the agent. A flow references it as a node:

```yaml
assistant:
  dw.agent:
    user_text: "{{in.input.text}}"
  operation: demo_assistant
```

At build time `greentic-pack` emits the dw sidecars:

- `dw-agents.json` — the `demo_assistant` `AgentConfig`.
- `secrets-policy.json` — `llm/deepseek` + `tavily/api_key`, both `byo-required` (the installer supplies their own keys; no secret values ship in the pack).

## Build

Requires `greentic-pack` (with `dw-application` support) on `PATH` and network access to resolve the Tavily store extension:

```bash
GREENTIC_STORE_URL=https://store.greentic.cloud \
  greentic-pack build --in crates/agentic-research-tavily-agent
# → crates/agentic-research-tavily-agent/dist/agentic-research-tavily-agent.gtpack
```

The committed artifact lives at `demos/agentic-research-tavily-agent.gtpack`.

## Publish to the store

Use a store token from your environment — never inline it in a command that gets shell-logged or committed:

```bash
export GREENTIC_STORE_TOKEN=gts_...   # from the store; keep it out of history/commits
greentic-pack publish-agent demos/agentic-research-tavily-agent.gtpack \
  --id "<handle>.agentic-research-tavily-agent" \
  --name "Tavily Research Agent" \
  --version 0.1.0 \
  --summary "Web research Agentic Worker (DeepSeek + Tavily)"
```

A second publish of the same id+version returns a non-fatal `already published (409)`.

## Install

Install via the store's agentic-worker install route (or the designer pointed at the store). The pack lands in `~/.greentic/dw-agents/packs/` and registers in `index.json`; the designer's agent picker then lists `demo_assistant`.

The installer must provide the `llm/deepseek` and `tavily/api_key` secrets (byo-required) before running the worker.
