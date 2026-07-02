# github-review-demo

A Greentic **OAuth bake-in** demo for GitHub. It replaces the old, non-building
`github-mcp-demo` stub.

A GitHub Review Assistant walks **org → repo → open PRs / failed CI / releases**.
Every step is a real MCP call (`component.exec`) against the OAuth-aware
`github_reports` component. On the first call with no token, the component
self-gates: the run pauses (`Wait`) and the **runtime's native OAuth engine**
(security scheme `githubOAuth`, PKCE + offline refresh) delivers a GitHub
sign-in card. **No OIDC provider pack is bundled** — the runtime handles the
OAuth dance natively.

## What's in the pack

```
generated-pack/
  pack.yaml                       # adaptive-card + github_reports components
  flows/main.ygtc                 # org/repo/PRs/CI/releases wizard, gate self-gates on OAuth
  assets/setup.yaml               # native OAuth questions: auth.oauth2.githubOAuth.client_id/secret
  assets/cards/*.json             # org / repo / prs / ci / releases cards
  components/github_reports/      # OAuth-aware MCP component (http-client + secrets-store)
  components/adaptive-card/
```

The OAuth credentials are pack-scoped secrets keyed by the pack id
(`github-review-pack`): the bundle author supplies `client_id` / `client_secret`
once at `gtc setup`; the customer only does the sign-in dance at runtime.

## Build

```bash
scripts/package_demos.sh github-review-demo
```

Produces `demos/github-review.gtpack` and `demos/github-review-demo.gtbundle`.
The bundle pulls two extension providers from GHCR: `messaging-webchat-gui` and
`state-memory` — and nothing OAuth-related, because the runtime handles OAuth
natively.

## Connecting a real GitHub account

Create a GitHub OAuth App (Settings → Developer settings → OAuth Apps) with
authorization callback URL `http://localhost:8080/oauth/callback/github`, then at
setup provide:

- `auth.oauth2.githubOAuth.client_id`
- `auth.oauth2.githubOAuth.client_secret`

Scopes used by the assistant: `repo`, `read:org`. Without credentials the demo
still runs and shows the sign-in card.
