use std::env;
use std::path::PathBuf;
use std::time::Duration;

use anyhow::{Result, anyhow, bail};

/// Minimal fallback config used only when `use-runner-api` is disabled.
#[derive(Clone, Debug)]
pub struct RunnerConfig {
    pub bindings: Vec<PathBuf>,
    pub port: u16,
    pub secrets_backend: String,
    pub pack_source: String,
    pub pack_index_url: String,
    pub pack_cache_dir: String,
    pub pack_public_key: Option<String>,
    pub pack_refresh_interval: Duration,
    pub tenant_resolver: Option<String>,
}

impl RunnerConfig {
    pub fn from_env(bindings: Vec<PathBuf>) -> Result<Self> {
        if bindings.is_empty() {
            bail!("at least one bindings file is required");
        }
        let port = env_var("PORT", 8080);
        let secrets_backend = env::var("SECRETS_BACKEND").unwrap_or_else(|_| "env".into());
        let pack_source = env::var("PACK_SOURCE").unwrap_or_else(|_| "fs".into());
        let pack_index_url =
            env::var("PACK_INDEX_URL").unwrap_or_else(|_| "./examples/index.json".into());
        let pack_cache_dir = env::var("PACK_CACHE_DIR").unwrap_or_else(|_| ".packs".into());
        let pack_public_key = env::var("PACK_PUBLIC_KEY").ok();
        let pack_refresh_interval = parse_refresh_interval();
        let tenant_resolver = env::var("TENANT_RESOLVER").ok();

        Ok(Self {
            bindings,
            port,
            secrets_backend,
            pack_source,
            pack_index_url,
            pack_cache_dir,
            pack_public_key,
            pack_refresh_interval,
            tenant_resolver,
        })
    }
}

pub async fn run(cfg: RunnerConfig) -> Result<()> {
    tracing::warn!(
        ?cfg,
        "runner-shim fallback is a no-op; enable the use-runner-api feature for full functionality"
    );
    Ok(())
}

fn env_var<T>(key: &str, default: T) -> T
where
    T: std::str::FromStr,
{
    env::var(key)
        .ok()
        .and_then(|value| value.parse().ok())
        .unwrap_or(default)
}

fn parse_refresh_interval() -> Duration {
    if let Ok(raw) = env::var("PACK_REFRESH_INTERVAL") {
        if let Some(duration) = parse_duration_string(&raw) {
            return duration;
        }
    }

    env::var("PACK_REFRESH_INTERVAL_SECS")
        .ok()
        .and_then(|value| value.parse::<u64>().ok())
        .map(Duration::from_secs)
        .unwrap_or_else(|| Duration::from_secs(30))
}

fn parse_duration_string(raw: &str) -> Option<Duration> {
    if let Ok(secs) = raw.parse::<u64>() {
        return Some(Duration::from_secs(secs));
    }

    let normalized = raw.trim();
    if let Some(stripped) = normalized
        .strip_suffix('s')
        .or_else(|| normalized.strip_suffix('S'))
    {
        return stripped.trim().parse::<u64>().ok().map(Duration::from_secs);
    }

    None
}
