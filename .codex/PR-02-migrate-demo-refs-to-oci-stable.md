Title: Migrate demo docs and answer files to OCI stable refs

## Summary

Update `greenticai/greentic-demo` so published demo instructions and committed answer files use stable GHCR OCI artifact refs instead of GitHub Release download URLs, raw JSON URLs, or `latest` demo artifact refs.

New public standard:

```text
oci://ghcr.io/greenticai/answers/<demo-name>/create:stable
oci://ghcr.io/greenticai/answers/<demo-name>/setup:stable
oci://ghcr.io/greenticai/answers/<demo-name>/create-aws:stable
oci://ghcr.io/greenticai/answers/<demo-name>/setup-aws:stable
oci://ghcr.io/greenticai/packs/demos/<pack-name>:stable
```

Important dependency: this PR must not switch user-facing docs or committed answer files to `oci://...:stable` unless the publish path also publishes those GHCR artifacts with the `stable` tag. The stable refs need to exist for both answer JSON artifacts and demo `.gtpack` artifacts.

## Dependency On PR-01

PR-01 introduces GHCR publishing for:

- demo answer JSON artifacts under `ghcr.io/greenticai/answers/...`
- demo `.gtpack` artifacts under `ghcr.io/greenticai/packs/demos/...`
- raw JSON answer media types accepted by `gtc`

This PR builds on that and must extend the publishing behavior to include a `:stable` tag. If PR-01 has not landed yet, include the stable-tag publishing changes here or keep this PR blocked until those artifacts are published.

Required publishing behavior before migration:

- `ghcr.io/${OWNER}/answers/${demo}/create:stable`
- `ghcr.io/${OWNER}/answers/${demo}/setup:stable`
- `ghcr.io/${OWNER}/answers/${demo}/create-aws:stable` when that answer exists
- `ghcr.io/${OWNER}/answers/${demo}/setup-aws:stable` when that answer exists
- `ghcr.io/${OWNER}/packs/demos/${pack}:stable`

For answer files, preserve raw JSON bytes and JSON-compatible media types:

- `application/vnd.greentic.answers.create.v1+json`
- `application/vnd.greentic.answers.setup.v1+json`

For packs, preserve:

- `application/vnd.greentic.gtpack.v1+zip`

Recommended publishing rule:

- publish `:stable` from the protected release branch (`main` or `master`) after packaging and validation pass
- keep `:latest` only for explicitly documented local/internal smoke testing, or remove it from public docs entirely

## Current Repo State

Local search found old artifact refs in the repo. The search included `README.md`, `scripts`, `crates`, `demos`, and `.github`. There is currently no `docs/` directory.

High-signal findings:

- `README.md` uses GitHub Release download answer URLs for demo create/setup examples.
- `crates/quickstart-event-demo/README.md` uses GitHub Release download answer URLs.
- Multiple crate READMEs use local `demos/*-create-answers.json` and `demos/*-setup-answers.json` examples.
- `scripts/publish_demo.sh` documents and generates GitHub Release download `.gtpack` URLs.
- `scripts/package_demos.sh` has packaging logic that rewrites `/download/*.gtpack` refs to local temp pack paths for bundle creation.
- `.github/workflows/publish.yml` still mentions release upload assets.
- Several committed demo create answer files reference GitHub Release download `.gtpack` artifacts.
- `crates/weather-mcp-demo/build-answer.json` references a GitHub Release download `.gtpack` artifact.

Specific artifact refs found:

- `README.md`: release-download create/setup JSON examples for `quickstart`, `hr-onboarding`, `helpdesk-itsm`, `sales-crm`, `supply-chain`, `incident`, `redbutton`, `cloud-deploy-demo`, `weather-mcp-demo`, `deep-research-demo`, and `telco-x-demo`.
- `crates/quickstart-event-demo/README.md`: release-download create/setup JSON examples.
- `demos/hr-onboarding-create-answers.json`: `hr-onboarding.gtpack` release URL.
- `demos/greentic-ai-create-answers.json`: `greentic-ai.gtpack` release URL.
- `demos/deep-research-demo-create-answers.json`: `deep-research-demo.gtpack` release URL.
- `demos/incident-create-answers.json`: `incident-demo.gtpack` release URL.
- `demos/cloud-deploy-demo-create-answers.json`: `cloud-deploy-demo-app.gtpack` release URL.
- `demos/helpdesk-itsm-create-answers.json`: `helpdesk-itsm.gtpack` release URL.
- `demos/supply-chain-create-answers.json`: `supply-chain.gtpack` release URL.
- `demos/sales-crm-create-answers.json`: `sales-crm.gtpack` release URL.
- `demos/weather-mcp-demo-create-answers.json`: `weatherapi-pack.gtpack` release URL.
- `crates/weather-mcp-demo/build-answer.json`: `weatherapi-pack.gtpack` release URL.

The repo also contains ordinary external URLs that must not be migrated, for example:

- `https://api.openai.com/v1`
- `https://platform.openai.com/api-keys`
- `https://ollama.com/download`
- `https://slack.com/api`
- `https://webexapis.com/v1`
- `https://example.com`
- `http://localhost:8080`
- `http://127.0.0.1:8080`
- schema URLs and Cargo registry URLs

## Proposed Changes

### 1. Publish Stable GHCR Tags

Update the GHCR publish path from PR-01, or the current publish scripts if PR-01 is not landed yet, so stable tags are produced before docs and answers point to them.

In `scripts/publish_demo_artifacts_oci.sh` or equivalent:

- publish answer JSON with `:stable` when publishing from `main` or `master`
- publish demo packs with `:stable` when publishing from `main` or `master`
- write stable refs to `.artifacts/answer-refs.txt` and `.artifacts/pack-refs.txt`

In fast dev scripts:

- keep `TAG=<custom>` behavior
- optionally allow `PUBLISH_STABLE=1` only for maintainers who intentionally update stable refs
- do not make ad hoc dev pushes update `:stable` by default

This is the core safety requirement for the migration. Every `oci://...:stable` ref introduced by this PR must correspond to an artifact that the repo publishes to GHCR.

### 2. Update README And Docs

Update `README.md` examples from GitHub Release JSON URLs to OCI stable answer refs.

Before:

```bash
gtc wizard --answers https://github.com/greenticai/greentic-demo/releases/latest/download/quickstart-create-answers.json
gtc setup ./quickstart-demo-bundle --answers https://github.com/greenticai/greentic-demo/releases/latest/download/quickstart-setup-answers.json
```

After:

```bash
gtc wizard \
  --answers oci://ghcr.io/greenticai/answers/quickstart/create:stable

gtc setup \
  --answers oci://ghcr.io/greenticai/answers/quickstart/setup:stable \
  ./quickstart-demo-bundle
```

Apply the same pattern to all public demo examples:

- `quickstart`
- `hr-onboarding`
- `helpdesk-itsm`
- `sales-crm`
- `supply-chain`
- `incident`
- `redbutton`
- `cloud-deploy-demo`
- `weather-mcp-demo`
- `deep-research-demo`
- `telco-x-demo`
- `quickstart-event` in `crates/quickstart-event-demo/README.md`

Add a note:

```text
Use :stable for published demo instructions. Use :latest only for local/internal smoke testing when explicitly documented.
```

If legacy GitHub Release URLs remain anywhere in docs, label them as legacy fallback and exclude them explicitly in the check script.

### 3. Update Committed Answer Files

Inspect and update every committed answer file:

- `demos/*-create-answers.json`
- `demos/*-setup-answers.json`
- `crates/**/build-answer.json`
- `crates/**/gtc_*answers*.json`
- `crates/**/pack_answers.json`

For each file:

- validate that it is valid JSON
- find values that reference demo packs, demo bundles, create answer JSON, setup answer JSON, or GitHub Release downloads
- replace Greentic demo artifact distribution refs with `oci://...:stable`
- keep local development file paths when they are intentionally used by packaging scripts
- keep ordinary external URLs unchanged

Pack replacement examples:

```text
https://github.com/greenticai/greentic-demo/releases/latest/download/weatherapi-pack.gtpack
-> oci://ghcr.io/greenticai/packs/demos/weatherapi-pack:stable

https://github.com/greenticai/greentic-demo/releases/latest/download/deep-research-demo.gtpack
-> oci://ghcr.io/greenticai/packs/demos/deep-research-demo:stable
```

When replacing an `app_pack_entries[].reference` value, also update its detected kind if present:

```json
"detected_kind": "oci"
```

Do not migrate local pack paths that are intentionally local for packaging, such as:

- `demos/quickstart.gtpack`
- `file://demos/quickstart.gtpack`
- `demos/quickstart-event.gtpack`
- `file://demos/telco-x.gtpack`

Document those exceptions in comments in `scripts/check_demo_refs.sh` or in the PR description. They are local packaging inputs, not public distribution refs.

### 4. Deep Research AWS Variant

Use these public stable refs:

```text
oci://ghcr.io/greenticai/answers/deep-research-demo/create:stable
oci://ghcr.io/greenticai/answers/deep-research-demo/setup:stable
oci://ghcr.io/greenticai/answers/deep-research-demo/create-aws:stable
oci://ghcr.io/greenticai/answers/deep-research-demo/setup-aws:stable
```

Current repo note:

- `demos/deep-research-demo-create-answers.json` exists.
- `demos/deep-research-demo-setup-answers.json` exists.
- `demos/deep-research-demo-aws-create-answers.json` was not present during the PR-01 inspection.
- `demos/deep-research-demo-aws-setup-answers.json` was not present during the PR-01 inspection.

If the AWS files have been added by the time this PR is implemented, migrate them and include them in stable publishing. If they are still absent, do not add docs pointing users to AWS stable refs until the answer files and GHCR publishing entries exist.

### 5. Add Reference Guard Script

Add `scripts/check_demo_refs.sh`.

Purpose:

- fail CI if committed docs, scripts, workflows, or answer files reintroduce old Greentic demo artifact refs
- fail CI if public Greentic demo OCI artifact refs use `:latest`
- validate committed answer JSON files

Scan at least:

- `README.md`
- `docs/` when present
- `scripts/`
- `crates/`
- `demos/`
- `.github/`

Fail on Greentic demo artifact refs matching:

```text
github.com/greenticai/greentic-demo/releases/latest/download
raw.githubusercontent.com/greenticai/greentic-demo
/releases/latest/download/.*-(create|setup)-answers\.json
/releases/latest/download/.*\.gtpack
/latest/.*-(create|setup)-answers\.json
oci://ghcr.io/greenticai/answers/.+:latest
oci://ghcr.io/greenticai/packs/demos/.+:latest
```

Allow:

```text
oci://ghcr.io/greenticai/answers/<demo>/<artifact>:stable
oci://ghcr.io/greenticai/packs/demos/<pack>:stable
```

Avoid false positives:

- do not fail on ordinary external URLs
- do not fail on schema URLs
- do not fail on local paths like `demos/foo-create-answers.json` when they are local development examples
- keep any exclusions explicit and commented

JSON validation:

- every committed answer JSON file must parse
- every committed create/setup answer JSON file should have a top-level JSON object

Suggested implementation outline:

```bash
#!/usr/bin/env bash
set -euo pipefail

roots=(README.md scripts crates demos .github)
[ -d docs ] && roots+=(docs)

# artifact-ref rg checks here
# jq validation over demos/*-create-answers.json demos/*-setup-answers.json crates/**/build-answer.json ...
```

### 6. Add Tests For The Guard

Add `scripts/test_check_demo_refs.sh` if no broader harness exists.

Minimum cases:

- fails on GitHub Release create answer URL
- fails on GitHub Release setup answer URL
- fails on GitHub Release `.gtpack` URL
- fails on `oci://ghcr.io/greenticai/answers/foo/create:latest`
- fails on `oci://ghcr.io/greenticai/packs/demos/foo:latest`
- passes on `oci://ghcr.io/greenticai/answers/foo/create:stable`
- passes on `oci://ghcr.io/greenticai/answers/foo/setup:stable`
- passes on `oci://ghcr.io/greenticai/packs/demos/foo:stable`
- passes on ordinary external URLs like `https://example.com`
- passes on OAuth/docs/service URLs
- validates all committed answer JSON files are JSON objects

The test can create temporary fixtures under `/tmp`, call `scripts/check_demo_refs.sh` with an optional root override, and assert exit codes.

### 7. Add CI Integration

If there is no general PR CI workflow, add:

- `.github/workflows/check-demo-refs.yml`

Triggers:

```yaml
on:
  pull_request:
  push:
    branches: [main]
```

Steps:

```yaml
- uses: actions/checkout@v4
- name: Install jq
  run: sudo apt-get update && sudo apt-get install -y jq
- name: Check demo refs
  run: scripts/check_demo_refs.sh
```

Also run `scripts/check_demo_refs.sh` before publishing in `.github/workflows/publish.yml`, so publishing cannot produce or bless stale refs.

### 8. Coordinate With Packaging

`scripts/package_demos.sh` currently rewrites `/download/*.gtpack` refs to local temp pack files when building bundles. After migration, answer files may contain `oci://ghcr.io/greenticai/packs/demos/<pack>:stable` instead of `/download/<pack>.gtpack`.

Update packaging logic as needed so local packaging still works:

- either recognize `oci://ghcr.io/greenticai/packs/demos/<pack>:stable` and map it to `$LOCAL_PACK_INPUT_DIR/<pack>.gtpack` during package-time bundle creation
- or keep intentionally local answer files for packaging and generate public distribution answers separately

Do not leave the repo in a state where `scripts/package_demos.sh` can no longer build bundles after answer files move to OCI stable refs.

## Replacement Map

Use this pattern for answer JSON docs:

```text
<demo>-create-answers.json -> oci://ghcr.io/greenticai/answers/<demo>/create:stable
<demo>-setup-answers.json  -> oci://ghcr.io/greenticai/answers/<demo>/setup:stable
```

Use this pattern for demo packs:

```text
<pack>.gtpack -> oci://ghcr.io/greenticai/packs/demos/<pack>:stable
```

Concrete pack refs seen in current files:

```text
cloud-deploy-demo-app.gtpack -> oci://ghcr.io/greenticai/packs/demos/cloud-deploy-demo-app:stable
deep-research-demo.gtpack    -> oci://ghcr.io/greenticai/packs/demos/deep-research-demo:stable
greentic-ai.gtpack           -> oci://ghcr.io/greenticai/packs/demos/greentic-ai:stable
helpdesk-itsm.gtpack         -> oci://ghcr.io/greenticai/packs/demos/helpdesk-itsm:stable
hr-onboarding.gtpack         -> oci://ghcr.io/greenticai/packs/demos/hr-onboarding:stable
incident-demo.gtpack         -> oci://ghcr.io/greenticai/packs/demos/incident-demo:stable
sales-crm.gtpack             -> oci://ghcr.io/greenticai/packs/demos/sales-crm:stable
supply-chain.gtpack          -> oci://ghcr.io/greenticai/packs/demos/supply-chain:stable
weatherapi-pack.gtpack       -> oci://ghcr.io/greenticai/packs/demos/weatherapi-pack:stable
```

## Validation

Run after implementation:

```bash
scripts/check_demo_refs.sh
scripts/test_check_demo_refs.sh
```

Also run JSON validation explicitly if not already included:

```bash
find demos crates -type f \
  \( -name '*-create-answers.json' -o -name '*-setup-answers.json' -o -name 'build-answer.json' -o -name 'gtc_*answers*.json' -o -name 'pack_answers.json' \) \
  -exec jq -e 'type == "object"' {} \;
```

## Acceptance Criteria

- Public README/docs examples use `oci://...:stable` for Greentic demo answer and pack artifacts.
- Committed demo answer files use `oci://...:stable` for Greentic demo artifact distribution refs.
- The publish path creates the `:stable` GHCR answer artifacts and demo pack artifacts referenced by docs and answer files.
- Deep research standard refs use:
  - `oci://ghcr.io/greenticai/answers/deep-research-demo/create:stable`
  - `oci://ghcr.io/greenticai/answers/deep-research-demo/setup:stable`
- Deep research AWS refs are documented only if the answer files exist and are published:
  - `oci://ghcr.io/greenticai/answers/deep-research-demo/create-aws:stable`
  - `oci://ghcr.io/greenticai/answers/deep-research-demo/setup-aws:stable`
- No default docs point to GitHub Release `latest/download/*.json`.
- No default docs point to `raw.githubusercontent.com` answer JSON.
- No default docs point to `oci://...:latest` for published Greentic demo artifacts.
- `scripts/check_demo_refs.sh` exists and fails on old artifact refs.
- CI runs the check on PRs and main branch pushes.
- The publish workflow runs the check before publishing.
- Ordinary non-artifact HTTPS URLs are left untouched.
- Packaging scripts still work after answer-file artifact refs move to OCI stable refs.
