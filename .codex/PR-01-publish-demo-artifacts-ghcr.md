Title: Publish demo packs and answer JSON artifacts to GHCR

## Summary

Change `greenticai/greentic-demo` demo publishing so demo `.gtpack` files and demo create/setup answer JSON files are published to GHCR as OCI artifacts. The normal publish workflow should stop creating/updating GitHub Releases and attaching every demo artifact by default.

The key behavioral requirement is that answer JSON artifacts are pushed as raw JSON bytes with JSON-compatible media types:

- `application/vnd.greentic.answers.create.v1+json`
- `application/vnd.greentic.answers.setup.v1+json`

These are accepted by `gtc wizard --answers oci://...` and `gtc setup --answers oci://...` because `gtc` validates direct OCI answer pulls as `application/json` or media types ending in `+json`, then parses the bytes as a top-level JSON object.

## Current Repo State

Files inspected:

- `.github/workflows/publish.yml`
- `scripts/package_demos.sh`
- `scripts/publish_demo_bundles_oci.sh`
- `README.md`
- `demos/*-create-answers.json`
- `demos/*-setup-answers.json`

Current behavior:

- `.github/workflows/publish.yml` is named `Publish Demo Bundles`.
- `publish-demos` runs `scripts/package_demos.sh`.
- `publish-demos` detects only `demos/*.gtbundle` and `demos/*.gtpack`.
- `publish-demos` uploads only bundle/pack workflow artifacts.
- `publish-demos` calls `scripts/publish_demo_bundles_oci.sh`.
- `publish-demos` creates/updates a GitHub Release whenever `publish_version` is set.
- `publish-demos` attaches `demos/*.gtbundle`, `demos/*.gtpack`, `demos/*-create-answers.json`, and `demos/*-setup-answers.json` to the release.
- `scripts/publish_demo_bundles_oci.sh` publishes bundles to `ghcr.io/${OWNER}/bundles/${bundle_name}:<tag>`.
- `scripts/publish_demo_bundles_oci.sh` publishes packs to `ghcr.io/${OWNER}/packs/demos/${pack_name}:<tag>` using `application/vnd.greentic.gtpack.v1+zip`.
- `scripts/publish_demo_bundles_oci.sh` writes `.artifacts/bundle-refs.txt` and `.artifacts/pack-refs.txt`.
- `scripts/package_demos.sh` still builds `.gtpack` and `.gtbundle` files and validates expected bundle/pack outputs.
- `README.md` documents release-download answer URLs, not OCI answer refs.

Important mismatch with requested file list:

- `demos/deep-research-demo-create-answers.json` exists.
- `demos/deep-research-demo-setup-answers.json` exists.
- `demos/deep-research-demo-aws-create-answers.json` is not currently present.
- `demos/deep-research-demo-aws-setup-answers.json` is not currently present.

The implementation should either add those AWS variant answer files as part of this PR or include tests/manifest entries only after the files exist.

## Proposed Changes

### 1. Add Answer Artifact Helper

Add `scripts/lib/demo_answer_artifacts.py`.

Responsibilities:

- List answer artifacts from `DEMOS_DIR`.
- Validate that each answer file is valid JSON.
- Validate that each answer file has a top-level JSON object.
- Resolve the publishing tuple:
  - source file
  - demo name
  - artifact name
  - media type
  - GHCR ref path
- Generate deterministic refs for tests and shell scripts.

Preferred CLI:

```bash
python3 scripts/lib/demo_answer_artifacts.py list demos
python3 scripts/lib/demo_answer_artifacts.py ref demos/deep-research-demo-create-answers.json
python3 scripts/lib/demo_answer_artifacts.py validate demos/deep-research-demo-create-answers.json
```

Mapping rules:

- `demos/<demo>-create-answers.json` -> `answers/<demo>/create`
- `demos/<demo>-setup-answers.json` -> `answers/<demo>/setup`
- `demos/<demo>-<variant>-create-answers.json` -> `answers/<demo>/create-<variant>`
- `demos/<demo>-<variant>-setup-answers.json` -> `answers/<demo>/setup-<variant>`

Because demo names contain hyphens, avoid first-hyphen parsing. Use either a manifest or a known-demo-name approach. The robust option for this repo is to add `demos/demo-artifacts.json` and let the helper use it as the source of truth.

Add `demos/demo-artifacts.json` with `answers` entries for all current `demos/*-create-answers.json` and `demos/*-setup-answers.json` files. Include deep-research AWS entries when those files are added:

```json
{
  "answers": [
    {
      "demo": "deep-research-demo",
      "file": "demos/deep-research-demo-create-answers.json",
      "artifact": "create",
      "media_type": "application/vnd.greentic.answers.create.v1+json"
    },
    {
      "demo": "deep-research-demo",
      "file": "demos/deep-research-demo-setup-answers.json",
      "artifact": "setup",
      "media_type": "application/vnd.greentic.answers.setup.v1+json"
    },
    {
      "demo": "deep-research-demo",
      "file": "demos/deep-research-demo-aws-create-answers.json",
      "artifact": "create-aws",
      "media_type": "application/vnd.greentic.answers.create.v1+json"
    },
    {
      "demo": "deep-research-demo",
      "file": "demos/deep-research-demo-aws-setup-answers.json",
      "artifact": "setup-aws",
      "media_type": "application/vnd.greentic.answers.setup.v1+json"
    }
  ]
}
```

### 2. Replace Main OCI Publish Script

Add `scripts/publish_demo_artifacts_oci.sh`.

Behavior:

- Requires `OWNER`.
- Requires `SHA`.
- Uses `DEMOS_DIR`, defaulting to `demos`.
- Uses `ARTIFACTS_DIR`, defaulting to `.artifacts`.
- Uses `PUBLISH_BUNDLES`, defaulting to `0`.
- Publishes existing `demos/*.gtpack` to `ghcr.io/${OWNER}/packs/demos/${pack_name}:<tag>`.
- Publishes answer JSON files to `ghcr.io/${OWNER}/answers/${demo_name}/${answer_artifact}:<tag>`.
- Publishes `.gtbundle` files only when `PUBLISH_BUNDLES=1`.
- Writes `.artifacts/pack-refs.txt`.
- Writes `.artifacts/answer-refs.txt`.
- Optionally writes `.artifacts/bundle-refs.txt` only when bundle publishing is enabled.

Tags:

- Always publish `:${SHA}`.
- Publish `:latest` when `BRANCH_NAME` is `main` or `master` or when `REF_NAME` is `main` or `master`.
- Publish `:${PUBLISH_VERSION}` when `PUBLISH_VERSION` is set.

Use ORAS with explicit media types:

```bash
oras push --disable-path-validation \
  "ghcr.io/${OWNER}/answers/${demo_name}/${artifact}:${tag}" \
  "${file}:${media_type}"
```

For packs:

```bash
oras push --disable-path-validation \
  "ghcr.io/${OWNER}/packs/demos/${pack_name}:${tag}" \
  "${pack_path}:application/vnd.greentic.gtpack.v1+zip"
```

Unlike the current `scripts/publish_demo_bundles_oci.sh`, this script should fail with a clear error when `oras` is missing because publishing is the point of the script.

### 3. Keep Backward-Compatible Wrapper

Change `scripts/publish_demo_bundles_oci.sh` into a temporary wrapper:

```bash
#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/publish_demo_artifacts_oci.sh" "$@"
```

### 4. Add Fast Answer Publish Script

Add `scripts/publish_demo_answers_oci.sh`.

Purpose:

- Push create/setup answer JSON to GHCR without running `gtc wizard`.
- Push answer JSON without running `gtc setup`.
- Push answer JSON without building bundles or packs.

Usage:

```bash
oras login ghcr.io

OWNER=greenticai TAG=dev-maarten scripts/publish_demo_answers_oci.sh
OWNER=greenticai TAG=dev-maarten scripts/publish_demo_answers_oci.sh deep-research-demo
OWNER=greenticai TAG=dev-maarten scripts/publish_demo_answers_oci.sh demos/deep-research-demo-create-answers.json
PUBLISH_LATEST=1 OWNER=greenticai TAG=dev-maarten scripts/publish_demo_answers_oci.sh
```

Behavior:

- Requires `oras`.
- Requires `jq`.
- Requires `OWNER`.
- Uses `TAG` when provided.
- Defaults `TAG` to the current git SHA.
- Publishes `:latest` only when `PUBLISH_LATEST=1`.
- Validates every JSON file with `jq`.
- Validates top-level JSON is an object.
- Refuses invalid JSON and top-level arrays before publishing.
- Publishes with the typed `+json` media types.
- Prints every pushed OCI ref.
- Writes `.artifacts/answer-refs.txt`.

### 5. Add Fast Pack Publish Script

Add `scripts/publish_demo_packs_oci.sh`.

Purpose:

- Push already-built `demos/*.gtpack` files to GHCR without rebuilding demos.

Usage:

```bash
oras login ghcr.io

OWNER=greenticai TAG=dev-maarten scripts/publish_demo_packs_oci.sh
OWNER=greenticai TAG=dev-maarten scripts/publish_demo_packs_oci.sh demos/deep-research-demo.gtpack
```

Behavior:

- Requires `oras`.
- Requires `OWNER`.
- Uses `TAG` when provided.
- Defaults `TAG` to the current git SHA.
- Publishes existing `.gtpack` files only.
- Uses `application/vnd.greentic.gtpack.v1+zip`.
- Writes `.artifacts/pack-refs.txt`.

### 6. Update GitHub Workflow

Update `.github/workflows/publish.yml`.

Workflow name:

```yaml
name: Publish Demo Artifacts
```

Add manual input:

```yaml
workflow_dispatch:
  inputs:
    create_github_release:
      description: "Create/update GitHub Release and attach demo artifacts"
      type: boolean
      default: false
```

In `publish-demos`:

- Continue running `scripts/package_demos.sh`.
- Detect packs and answers:
  - `demos/*.gtpack`
  - `demos/*-create-answers.json`
  - `demos/*-setup-answers.json`
- Upload workflow artifacts for visibility:
  - `demos/*.gtpack`
  - `demos/*-create-answers.json`
  - `demos/*-setup-answers.json`
- Call `scripts/publish_demo_artifacts_oci.sh`.
- Upload `.artifacts/pack-refs.txt`.
- Upload `.artifacts/answer-refs.txt`.
- Do not upload `.artifacts/bundle-refs.txt` unless `PUBLISH_BUNDLES=1`.

Gate the existing GitHub Release steps:

- `Ensure release exists`
- `Attach bundles and answers to release`
- `Verify attached demo release assets`

The default must be no GitHub Release creation and no release attachment. Use a condition equivalent to:

```yaml
if: >
  steps.artifacts.outputs.found == 'true' &&
  needs.resolve-version.outputs.publish_version != '' &&
  github.event_name == 'workflow_dispatch' &&
  inputs.create_github_release == true
```

### 7. Update Docs

Add `docs/publishing-demo-artifacts.md`.

Update `README.md`.

Document published refs:

```text
oci://ghcr.io/greenticai/packs/demos/<pack>:latest
oci://ghcr.io/greenticai/answers/<demo>/create:latest
oci://ghcr.io/greenticai/answers/<demo>/setup:latest
oci://ghcr.io/greenticai/answers/deep-research-demo/create-aws:latest
oci://ghcr.io/greenticai/answers/deep-research-demo/setup-aws:latest
```

Document usage:

```bash
gtc wizard \
  --answers oci://ghcr.io/greenticai/answers/deep-research-demo/create:latest

gtc setup \
  --answers oci://ghcr.io/greenticai/answers/deep-research-demo/setup:latest \
  ./my-bundle

gtc wizard \
  --answers oci://ghcr.io/greenticai/answers/deep-research-demo/create-aws:latest

gtc setup \
  --answers oci://ghcr.io/greenticai/answers/deep-research-demo/setup-aws:latest \
  ./my-bundle
```

Document development push:

```bash
oras login ghcr.io

OWNER=greenticai TAG=dev-maarten \
  scripts/publish_demo_answers_oci.sh deep-research-demo

gtc wizard \
  --answers oci://ghcr.io/greenticai/answers/deep-research-demo/create:dev-maarten
```

Also document:

- Create JSON is for `gtc wizard --answers`.
- Setup JSON is for `gtc setup --answers`.
- `create-aws` and `setup-aws` are the AWS variant for deep research.
- Do not put secrets in public demo answer artifacts.
- Direct `oci://` answer files must be JSON-compatible media types and raw JSON bytes, not tar/zip/pack/component blobs.

### 8. Tests

Add automated tests for `scripts/lib/demo_answer_artifacts.py`.

Suggested path:

- `scripts/test_demo_answer_artifacts.py`

Use Python standard-library `unittest` unless the repo already adopts another Python test runner.

Required coverage:

- `demos/foo-create-answers.json` maps to:
  - demo `foo`
  - artifact `create`
  - media type `application/vnd.greentic.answers.create.v1+json`
- `demos/foo-setup-answers.json` maps to:
  - demo `foo`
  - artifact `setup`
  - media type `application/vnd.greentic.answers.setup.v1+json`
- `demos/deep-research-demo-create-answers.json` maps to:
  - demo `deep-research-demo`
  - artifact `create`
- `demos/deep-research-demo-setup-answers.json` maps to:
  - demo `deep-research-demo`
  - artifact `setup`
- `demos/deep-research-demo-aws-create-answers.json` maps to:
  - demo `deep-research-demo`
  - artifact `create-aws`
- `demos/deep-research-demo-aws-setup-answers.json` maps to:
  - demo `deep-research-demo`
  - artifact `setup-aws`
- Every published answer file in `demos/demo-artifacts.json` is valid JSON.
- Every published answer file has a top-level JSON object.
- Invalid JSON is rejected before publish.
- Top-level array JSON is rejected before publish.
- Missing `oras` gives a clear error in the shell publish scripts.
- Generated ORAS refs match `ghcr.io/<owner>/answers/<demo>/<artifact>:<tag>`.

Also add a shell smoke test if useful:

- `scripts/test_publish_demo_answers_oci.sh`
- It can stub `oras` in `PATH` and assert the generated `oras push` arguments include the raw JSON file and typed `+json` media type.

## Acceptance Criteria

- Demo `.gtpack` files publish to `ghcr.io/<owner>/packs/demos/<pack>:<tag>`.
- Demo create/setup answer JSON files publish to `ghcr.io/<owner>/answers/<demo>/<artifact>:<tag>`.
- Answer OCI media types are `application/json` or end in `+json`.
- Answer JSON blobs are pushed as raw JSON bytes, not tar/zip.
- Deep research local refs publish as:
  - `oci://ghcr.io/<owner>/answers/deep-research-demo/create:<tag>`
  - `oci://ghcr.io/<owner>/answers/deep-research-demo/setup:<tag>`
- Deep research AWS refs publish as soon as the AWS files are added:
  - `oci://ghcr.io/<owner>/answers/deep-research-demo/create-aws:<tag>`
  - `oci://ghcr.io/<owner>/answers/deep-research-demo/setup-aws:<tag>`
- Publish workflow no longer creates/updates GitHub Releases or attaches every demo artifact by default.
- Fast script exists to publish answer JSON to GHCR without rebuilding demos.
- Fast script exists to publish already-built demo packs to GHCR without rebuilding demos.
- `.artifacts/answer-refs.txt` and `.artifacts/pack-refs.txt` are produced.
- Docs show `gtc wizard --answers oci://...` and `gtc setup --answers oci://...`.
- Tests cover answer mapping, media types, invalid JSON rejection, top-level object validation, and generated GHCR refs.

## Implementation Notes

- Keep `scripts/package_demos.sh` focused on packaging. Do not move GHCR publishing logic into it.
- Keep `scripts/publish_demo.sh` unchanged unless explicitly deciding to modernize one-off release publishing in a follow-up; it currently targets GitHub Release assets.
- For the main workflow, the release attachment gate should account for push/tag events where `inputs` may not be present.
- The current ORAS pack publishing path already matches the required pack layout and media type, so the pack work is mostly extraction/reuse.
- The current bundle publishing path should remain available only behind `PUBLISH_BUNDLES=1`.
- Prefer manifest-backed answer mapping so hyphenated demo names and variant names do not rely on fragile filename parsing.
