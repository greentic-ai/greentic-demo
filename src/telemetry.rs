use std::collections::HashMap;

use anyhow::{Context, Result};
use serde::Deserialize;

use crate::config::{TelemetryConfig, TelemetrySource};

pub struct TelemetryHandle;

impl Drop for TelemetryHandle {
    fn drop(&mut self) {
        greentic_telemetry::shutdown();
    }
}

#[derive(Debug, Deserialize)]
struct TelemetryPayload {
    #[serde(default)]
    service_name: Option<String>,
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
            set_env("SERVICE_NAME", &service_name);

            if let Some(otlp) = settings.otlp {
                if let Some(endpoint) = otlp.endpoint {
                    set_env("OTEL_EXPORTER_OTLP_ENDPOINT", endpoint);
                }

                if let Some(headers) = otlp.headers {
                    let header_str = headers
                        .into_iter()
                        .map(|(k, v)| format!("{k}={v}"))
                        .collect::<Vec<_>>()
                        .join(",");
                    if !header_str.is_empty() {
                        set_env("OTEL_EXPORTER_OTLP_HEADERS", header_str);
                    }
                }
            }

            greentic_telemetry::init_telemetry(greentic_telemetry::TelemetryConfig {
                service_name,
            })?;
            tracing::info!("greentic telemetry initialized via preconfigured payload");
            Ok(Some(TelemetryHandle))
        }
    }
}

fn set_env(key: &str, value: impl AsRef<str>) {
    unsafe {
        std::env::set_var(key, value.as_ref());
    }
}
