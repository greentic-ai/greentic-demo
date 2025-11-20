use anyhow::Result;
use serde::Deserialize;
use serde_json::json;
use std::env;
use std::fs;
use std::path::Path;

/// Minimal stub that emulates a deployment component:
/// - reads a DeploymentPlan JSON from the DEPLOYMENT_PLAN_JSON env var (or `{}` if missing)
/// - writes it to `/iac/plan.json`
/// - prints a status message to stdout
///
/// This is intended to be built for `wasm32-wasi` and dropped in place of the real
/// `greentic.deploy.generic.iac` component when testing locally.
fn main() -> Result<()> {
    let plan_json = env::var("DEPLOYMENT_PLAN_JSON").unwrap_or_else(|_| "{}".into());
    let plan: serde_json::Value = serde_json::from_str(&plan_json).unwrap_or_else(|_| json!({}));

    let out_dir = Path::new("/iac");
    fs::create_dir_all(out_dir)?;
    let out_path = out_dir.join("plan.json");
    let serialized = serde_json::to_string_pretty(&plan)?;
    fs::write(&out_path, serialized)?;

    let message = StatusMessage {
        message: "wrote plan.json".into(),
        path: out_path.display().to_string(),
    };
    println!("{}", serde_json::to_string(&message)?);
    Ok(())
}

#[derive(Deserialize, serde::Serialize)]
struct StatusMessage {
    message: String,
    path: String,
}
