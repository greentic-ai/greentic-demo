use std::time::Duration;

use anyhow::Result;
use clap::Parser;
use greentic_demo::config::{AppConfig, CliArgs};
use greentic_demo::health::HealthMonitor;
use greentic_demo::loader::load_packs;
use greentic_demo::logging;
use greentic_demo::nats_bridge::NatsBridge;
use greentic_demo::runner_bridge::RunnerBridge;

#[tokio::main]
async fn main() {
    if let Err(err) = run().await {
        eprintln!("greentic-demo failed: {err:?}");
        std::process::exit(1);
    }
}

async fn run() -> Result<()> {
    let args = CliArgs::parse();
    let config = AppConfig::from_args(&args)?;
    let _guard = logging::init_logging(&config)?;
    config.log_startup_warnings();
    config.validate()?;

    tracing::info!(mode = ?config.mode, packs = %config.packs_dir.display(), "launching greentic-demo");

    let packs = load_packs(&config.packs_dir)?;
    if packs.is_empty() {
        tracing::warn!("no packs discovered; bridge will start idle");
    }

    let health = HealthMonitor::new(Duration::from_secs(30));
    let _health_task = health.spawn_reporter();

    let runner = RunnerBridge::new(config.mode.clone(), config.allowed_secrets.clone());
    let mut active_tenants = Vec::new();
    for pack in &packs {
        match runner.register_pack(pack).await {
            Ok(_) => {
                tracing::info!(tenant = %pack.tenant, path = %pack.index_path.display(), "pack registered");
                active_tenants.push(pack.tenant.clone());
            }
            Err(err) => {
                tracing::error!(tenant = %pack.tenant, error = %err, "failed to register pack");
            }
        }
    }

    let bridge = NatsBridge::connect(&config, runner, active_tenants, health).await?;
    bridge.run().await
}
