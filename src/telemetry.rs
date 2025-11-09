use std::collections::HashMap;

use anyhow::{Context, Result};
use greentic_telemetry::{OtlpConfig, init_otlp};
use serde::Deserialize;

use crate::config::{TelemetryConfig, TelemetrySource};

pub struct TelemetryHandle;

#[derive(Debug, Deserialize)]
struct TelemetryPayload {
    #[serde(default)]
    service_name: Option<String>,
    #[serde(default)]
    sampling: Option<f64>,
    #[serde(default)]
    otlp: Option<OtlpPayload>,
}

#[derive(Debug, Deserialize, Default)]
struct OtlpPayload {
    #[serde(default)]
    endpoint: Option<String>,
    #[serde(default)]
    headers: Option<HashMap<String, String>>,
}

pub fn init(config: &TelemetryConfig) -> Result<Option<TelemetryHandle>> {
    match config {
        TelemetryConfig::Disabled => Ok(None),
        TelemetryConfig::Preconfigured { payload, source } => {
            let source_desc = match source {
                TelemetrySource::Env => "env var".to_string(),
                TelemetrySource::File(path) => format!("file {}", path.display()),
            };

            let settings: TelemetryPayload = serde_json::from_str(payload)
                .with_context(|| format!("invalid telemetry payload from {source_desc}"))?;

            let service_name = settings
                .service_name
                .unwrap_or_else(|| "greentic-demo".to_string());

            if let Some(otlp) = settings.otlp.as_ref().and_then(|o| o.headers.as_ref()) {
                let header_str = otlp
                    .iter()
                    .map(|(k, v)| format!("{k}={v}"))
                    .collect::<Vec<_>>()
                    .join(",");
                if !header_str.is_empty() {
                    // SAFETY: setting process env vars is safe within this process.
                    unsafe {
                        std::env::set_var("OTEL_EXPORTER_OTLP_HEADERS", header_str);
                    }
                }
            }

            init_otlp(
                OtlpConfig {
                    service_name: service_name.clone(),
                    endpoint: settings.otlp.and_then(|o| o.endpoint),
                    sampling_rate: settings.sampling,
                },
                Vec::new(),
            )
            .with_context(|| "failed to initialize greentic telemetry")?;

            tracing::info!(
                service = %service_name,
                source = %source_desc,
                "telemetry pipeline initialized"
            );

            Ok(Some(TelemetryHandle))
        }
    }
}
