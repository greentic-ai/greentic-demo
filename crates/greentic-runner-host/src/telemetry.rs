use std::sync::OnceLock;

use anyhow::Result;
use rand::{rng, Rng};
use tracing::Span;

use crate::config::HostConfig;

static ENV: OnceLock<String> = OnceLock::new();

pub fn init(config: &HostConfig) -> Result<()> {
    ENV.get_or_init(|| {
        std::env::var("DEPLOYMENT_ENV").unwrap_or_else(|_| match config.http_enabled {
            true => "prod".to_string(),
            false => "dev".to_string(),
        })
    });
    Ok(())
}

#[derive(Debug, Clone)]
pub struct FlowSpanAttributes<'a> {
    pub tenant: &'a str,
    pub flow_id: &'a str,
    pub node_id: Option<&'a str>,
    pub tool: Option<&'a str>,
    pub action: Option<&'a str>,
}

pub fn annotate_span(span: &Span, attrs: &FlowSpanAttributes<'_>) {
    span.record("tenant", attrs.tenant);
    span.record("flow_id", attrs.flow_id);
    if let Some(node) = attrs.node_id {
        span.record("node_id", node);
    }
    if let Some(tool) = attrs.tool {
        span.record("tool", tool);
    }
    if let Some(action) = attrs.action {
        span.record("action", action);
    }
}

pub fn set_flow_context(_tenant: &str, _flow_id: Option<&str>) {}

pub fn backoff_delay_ms(base: u64, attempt: u32) -> u64 {
    let multiplier = 1_u64 << attempt.min(10);
    let exp = base.saturating_mul(multiplier);
    let mut rng = rng();
    let jitter = rng.random_range(0..=exp.min(1000));
    exp + jitter
}
