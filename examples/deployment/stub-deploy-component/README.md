# Stub deployment component (WASM target)

This crate is a tiny stand-in for `greentic.deploy.generic.iac`:

- Reads a DeploymentPlan JSON from `DEPLOYMENT_PLAN_JSON` (or `{}` if absent).
- Writes the plan to `/iac/plan.json`.
- Prints a JSON status message to stdout.

Build for WASI:

```bash
rustup target add wasm32-wasi
cargo build --release --target wasm32-wasi
# copy the resulting .wasm to
# examples/deployment/generic-deploy.gtpack/components/greentic.deploy.generic.iac.wasm
```

Note: the repo does not ship the compiled `.wasm`; this stub is provided so you can
produce a local artifact without provider-specific logic.
