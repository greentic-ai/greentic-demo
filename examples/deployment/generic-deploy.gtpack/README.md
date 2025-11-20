# Generic Deployment Demo Pack

This pack illustrates the deployment pattern without baking in any provider semantics. It shows how a deployment flow can:

- Accept a `DeploymentPlan` via the generic `greentic:deploy-plan@1.0.0` world.
- Write IaC artifacts to a preopened `/iac` directory.
- Emit status updates about progress.

Files:
- `manifest.yaml` – declares `kind: deployment` plus the flows/components contained here.
- `flows/deploy_generic_iac.ygtc` – events flow that hands control to the deployment component.
- `flows/configure_greentic_deploy_generic_iac_basic.ygtc` – basic configurator flow for the deployment component.
- `components/greentic.deploy.generic.iac.yaml` – component manifest advertising `host.iac` capabilities and the deploy-plan world.

Binary note:
- The repo now includes a compiled stub `components/greentic.deploy.generic.iac.wasm` built from `../stub-deploy-component`. Rebuild if you change the stub:
  - `cd examples/deployment/stub-deploy-component`
  - `cargo build --release --target wasm32-wasip1`
  - copy `target/wasm32-wasip1/release/stub-deploy-component.wasm` over `components/greentic.deploy.generic.iac.wasm`
