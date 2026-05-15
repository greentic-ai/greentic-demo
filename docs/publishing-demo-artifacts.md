# Publishing demo artifacts

Demo packs and demo answer documents are published to GHCR as OCI artifacts.

## Published artifacts

Demo packs:

```text
oci://ghcr.io/greenticai/packs/demos/<pack>:latest
```

Create answers:

```text
oci://ghcr.io/greenticai/answers/<demo>/create:latest
```

Setup answers:

```text
oci://ghcr.io/greenticai/answers/<demo>/setup:latest
```

Deep research AWS variant answers, when present:

```text
oci://ghcr.io/greenticai/answers/deep-research-demo/create-aws:latest
oci://ghcr.io/greenticai/answers/deep-research-demo/setup-aws:latest
```

`gtc` pulls direct `oci://` answer refs through distributor-client OCI pull machinery. Answer artifacts must be raw JSON bytes with media type `application/json` or a media type ending in `+json`, such as:

```text
application/vnd.greentic.answers.create.v1+json
application/vnd.greentic.answers.setup.v1+json
```

Do not publish answer JSON as pack, component, zip, tar, or opaque binary media types. `gtc --answers` parses the pulled bytes as JSON and requires a top-level JSON object.

## Using published answers

Create a bundle:

```bash
gtc wizard \
  --answers oci://ghcr.io/greenticai/answers/deep-research-demo/create:latest
```

Set up a bundle:

```bash
gtc setup \
  --answers oci://ghcr.io/greenticai/answers/deep-research-demo/setup:latest \
  ./my-bundle
```

Deep research AWS variant:

```bash
gtc wizard \
  --answers oci://ghcr.io/greenticai/answers/deep-research-demo/create-aws:latest

gtc setup \
  --answers oci://ghcr.io/greenticai/answers/deep-research-demo/setup-aws:latest \
  ./my-bundle
```

Create JSON is for `gtc wizard --answers`. Setup JSON is for `gtc setup --answers`. Do not put secrets in public demo answer artifacts.

## Development pushes

Push answer JSON without rebuilding demos:

```bash
oras login ghcr.io

OWNER=greenticai TAG=dev-maarten \
  scripts/publish_demo_answers_oci.sh deep-research-demo
```

Use the pushed development answer:

```bash
gtc wizard \
  --answers oci://ghcr.io/greenticai/answers/deep-research-demo/create:dev-maarten
```

Push existing demo packs without rebuilding demos:

```bash
oras login ghcr.io

OWNER=greenticai TAG=dev-maarten \
  scripts/publish_demo_packs_oci.sh demos/deep-research-demo.gtpack
```

The normal publish workflow writes pushed refs to:

```text
.artifacts/answer-refs.txt
.artifacts/pack-refs.txt
```
