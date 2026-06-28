# agentic-research-tavily-demo

The first greentic-demo that runs an **Agentic Worker (`dw.agent`)** node inside a
messaging flow. Each incoming webchat message is routed to an embedded LLM
Plan-Act-Observe agent (`demo_assistant`), and the agent's answer is sent back to
the chat.

```bash
./scripts/package_demos.sh agentic-research-tavily-demo
gtc wizard --answers demos/agentic-research-tavily-demo-create-answers.json
gtc setup agentic-research-tavily-demo-bundle --answers demos/agentic-research-tavily-demo-setup-answers.json
GREENTIC_LLM_PROVIDER=deepseek \
GREENTIC_LLM_API_KEY=sk-your-deepseek-key \
GREENTIC_AW_REDIS_URL=redis://127.0.0.1:6379 \
gtc start agentic-research-tavily-demo-bundle
```

## Runtime requirements

The Agentic Worker runtime needs an LLM key and Redis at run time (none are baked
into the pack). Provide them as environment variables when you run `gtc start`:

| Variable | Purpose | Example |
|----------|---------|---------|
| `GREENTIC_LLM_PROVIDER` | LLM provider the agent uses | `deepseek` |
| `GREENTIC_LLM_API_KEY` | API key for that provider | `sk-...` |
| `GREENTIC_AW_REDIS_URL` | Redis the Agentic Worker uses for session state | `redis://127.0.0.1:6379` |

Start a local Redis first (for example `docker run -p 6379:6379 redis`).

## How it works

- `flows/on_message.ygtc` is a `messaging` flow with a single logic node,
  `assistant`, of type `dw.agent`. Its `operation` (`demo_assistant`) selects the
  embedded agent declared under `agents:` in `pack.yaml`.
- The agent receives the user's message text as `user_text` and returns `reply`.
- The builtin `emit.response` node (`send_reply`) routes that reply back to the
  active webchat channel.

## Packaging

- Standard demo build entrypoint: `./scripts/package_demos.sh agentic-research-tavily-demo`.
- Pack build answers (including the `pack_overlay` that injects the real flow and
  the `agents:` block) live in `build-answer.json`.
- Pack setup prompts live in `assets/setup.yaml`.
- Bundle creation answers live in `demos/agentic-research-tavily-demo-create-answers.json`.
- Bundle setup answers live in `demos/agentic-research-tavily-demo-setup-answers.json`.

## Components

| Node | Kind | Purpose |
|------|------|---------|
| `assistant` | `dw.agent` (Agentic Worker) | LLM agent that answers each message |
| `send_reply` | `emit.response` (builtin) | Sends the agent reply back to chat |

## License

MIT
