use std::fs::{self, OpenOptions};
use std::path::PathBuf;

use anyhow::{Context, Result};
use tracing_appender::non_blocking::WorkerGuard;
use tracing_subscriber::fmt::time::SystemTime;
use tracing_subscriber::{EnvFilter, fmt};

use crate::config::{AppConfig, LoggingConfig, Mode};
use crate::telemetry::{self, TelemetryHandle};

pub struct LoggingGuard {
    _guard: Option<WorkerGuard>,
    _telemetry: Option<TelemetryHandle>,
}

impl LoggingGuard {
    pub fn noop() -> Self {
        Self {
            _guard: None,
            _telemetry: None,
        }
    }
}

pub fn init_logging(config: &AppConfig) -> Result<LoggingGuard> {
    let log_guard = match &config.logging {
        LoggingConfig::DevFile { path } => init_dev_logging(path)?,
        LoggingConfig::Telemetry => init_prod_logging()?,
    };

    let telemetry_guard = telemetry::init(&config.telemetry)?;

    Ok(LoggingGuard {
        _guard: log_guard,
        _telemetry: telemetry_guard,
    })
}

fn init_dev_logging(path: &PathBuf) -> Result<Option<WorkerGuard>> {
    if let Some(parent) = path.parent() {
        if !parent.as_os_str().is_empty() {
            fs::create_dir_all(parent)
                .with_context(|| format!("failed to create log directory {parent:?}"))?;
        }
    }

    let file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(path)
        .with_context(|| format!("unable to open log file at {path:?}"))?;

    let (writer, guard) = tracing_appender::non_blocking(file);
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));

    fmt()
        .with_env_filter(filter)
        .with_timer(SystemTime)
        .with_writer(writer)
        .init();

    tracing::info!(mode = ?Mode::Dev, "dev logging initialized");
    Ok(Some(guard))
}

fn init_prod_logging() -> Result<Option<WorkerGuard>> {
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));

    fmt()
        .with_env_filter(filter)
        .with_timer(SystemTime)
        .json()
        .with_current_span(false)
        .init();

    tracing::info!(mode = ?Mode::Prod, "telemetry logging initialized");
    Ok(None)
}
