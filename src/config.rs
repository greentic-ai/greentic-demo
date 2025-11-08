use std::env;
use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result, bail};
use clap::Parser;

use crate::secrets;

/// Command-line arguments surfaced by the binary.
#[derive(Debug, Parser, Clone)]
#[command(author, version, about = "greentic demo server", long_about = None)]
pub struct CliArgs {
    /// Enables developer ergonomics: .env loading, local logging, unsecured NATS.
    #[arg(long, default_value_t = false)]
    pub dev: bool,

    /// Directory containing tenant packs (packs/<tenant>/index.ygtc).
    #[arg(long, default_value = "./packs")]
    pub packs_dir: PathBuf,

    /// Explicit NATS URL. Overrides env/secrets.
    #[arg(long, env = "NATS_URL")]
    pub nats_url: Option<String>,

    /// Optional override for the subject prefix (messaging.activities by default).
    #[arg(long, env = "SUBJECT_PREFIX", default_value = "messaging.activities")]
    pub subject_prefix: String,

    /// Comma-separated allow list of secrets accessible to packs (used for auto-generated bindings).
    #[arg(long, env = "RUNNER_ALLOWED_SECRETS", value_delimiter = ',', num_args = 0..)]
    pub allowed_secrets: Vec<String>,
}

#[derive(Debug, Clone)]
pub struct AppConfig {
    pub mode: Mode,
    pub packs_dir: PathBuf,
    pub nats: NatsConfig,
    pub logging: LoggingConfig,
    pub subjects: SubjectConfig,
    pub telemetry: TelemetryConfig,
    pub warnings: Vec<String>,
    pub allowed_secrets: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Mode {
    Dev,
    Prod,
}

#[derive(Debug, Clone)]
pub struct NatsConfig {
    pub url: String,
    pub auth: NatsAuth,
}

#[derive(Debug, Clone)]
pub enum NatsAuth {
    None,
    Jwt { jwt: String, seed: String },
}

#[derive(Debug, Clone)]
pub enum LoggingConfig {
    DevFile { path: PathBuf },
    Telemetry,
}

#[derive(Debug, Clone)]
pub enum TelemetryConfig {
    Disabled,
    Preconfigured {
        payload: String,
        source: TelemetrySource,
    },
}

impl TelemetryConfig {
    fn from_parts(payload: String, source: TelemetrySource) -> Self {
        TelemetryConfig::Preconfigured { payload, source }
    }

    pub fn is_enabled(&self) -> bool {
        matches!(self, TelemetryConfig::Preconfigured { .. })
    }
}

#[derive(Debug, Clone)]
pub enum TelemetrySource {
    Env,
    File(PathBuf),
}

impl TelemetrySource {
    pub fn as_str(&self) -> &'static str {
        match self {
            TelemetrySource::Env => "env",
            TelemetrySource::File(_) => "file",
        }
    }
}
#[derive(Debug, Clone)]
pub struct SubjectConfig {
    base: String,
}

impl SubjectConfig {
    pub fn new(base: impl Into<String>) -> Self {
        Self { base: base.into() }
    }

    pub fn ingress_subject(&self, tenant: &str) -> String {
        format!("{}.in.{}", self.base, tenant)
    }

    pub fn egress_subject(&self, tenant: &str) -> String {
        format!("{}.out.{}", self.base, tenant)
    }
}

impl AppConfig {
    pub fn from_args(args: &CliArgs) -> Result<Self> {
        if args.dev {
            load_dotenv();
            Self::dev(args)
        } else {
            Self::prod(args)
        }
    }

    fn dev(args: &CliArgs) -> Result<Self> {
        let mut warnings = Vec::new();
        let url = args
            .nats_url
            .clone()
            .or_else(|| env::var("NATS_URL").ok())
            .unwrap_or_else(|| "nats://127.0.0.1:4222".to_string());

        if env::var("NATS_JWT").is_err() || env::var("NATS_SEED").is_err() {
            warnings.push(
                "NATS_JWT/NATS_SEED not set; secured NATS stacks unavailable in --dev".to_string(),
            );
        }

        let telemetry = match telemetry_payload() {
            Ok(Some((payload, source))) => TelemetryConfig::from_parts(payload, source),
            Ok(None) => TelemetryConfig::Disabled,
            Err(err) => {
                warnings.push(format!("Telemetry config ignored in dev: {err}"));
                TelemetryConfig::Disabled
            }
        };

        Ok(Self {
            mode: Mode::Dev,
            packs_dir: normalize_path(&args.packs_dir),
            nats: NatsConfig {
                url,
                auth: NatsAuth::None,
            },
            logging: LoggingConfig::DevFile {
                path: PathBuf::from("demo.log"),
            },
            subjects: SubjectConfig::new(args.subject_prefix.clone()),
            telemetry,
            warnings,
            allowed_secrets: args.allowed_secrets.clone(),
        })
    }

    fn prod(args: &CliArgs) -> Result<Self> {
        let url = args
            .nats_url
            .clone()
            .map(Ok)
            .unwrap_or_else(|| secrets::read("NATS_URL"))?;

        let jwt = secrets::read("NATS_JWT")
            .context("NATS_JWT secret not found; retrieve via greentic-secrets")?;
        let seed = secrets::read("NATS_SEED")
            .or_else(|_| secrets::read("NATS_NKEY_SEED"))
            .context("NATS_SEED secret not found; retrieve via greentic-secrets")?;

        let telemetry = match telemetry_payload()? {
            Some((payload, source)) => TelemetryConfig::from_parts(payload, source),
            None => TelemetryConfig::Disabled,
        };

        Ok(Self {
            mode: Mode::Prod,
            packs_dir: normalize_path(&args.packs_dir),
            nats: NatsConfig {
                url,
                auth: NatsAuth::Jwt { jwt, seed },
            },
            logging: LoggingConfig::Telemetry,
            subjects: SubjectConfig::new(args.subject_prefix.clone()),
            telemetry,
            warnings: Vec::new(),
            allowed_secrets: args.allowed_secrets.clone(),
        })
    }

    pub fn log_startup_warnings(&self) {
        for warning in &self.warnings {
            tracing::warn!(%warning, "startup warning");
        }
    }

    pub fn validate(&self) -> Result<()> {
        if let Mode::Prod = self.mode {
            match &self.nats.auth {
                NatsAuth::Jwt { jwt, seed } => {
                    if jwt.trim().is_empty() {
                        bail!("NATS_JWT is empty; prod mode requires a valid JWT");
                    }
                    if seed.trim().is_empty() {
                        bail!("NATS_SEED is empty; prod mode requires a valid seed");
                    }
                }
                _ => bail!("prod mode requires JWT-based NATS credentials"),
            }
            if self.allowed_secrets.is_empty() {
                bail!(
                    "prod mode requires --allowed-secrets / RUNNER_ALLOWED_SECRETS so packs can declare permitted secrets"
                );
            }
        }

        Ok(())
    }
}

fn load_dotenv() {
    let default_paths = [".env", "env/.env"];
    for path in default_paths {
        if Path::new(path).exists() {
            let _ = dotenvy::from_filename(path);
            break;
        }
    }
}

fn normalize_path(path: &Path) -> PathBuf {
    if path.is_absolute() {
        path.to_path_buf()
    } else {
        PathBuf::from(path)
    }
}

fn telemetry_payload() -> Result<Option<(String, TelemetrySource)>> {
    if let Ok(value) = env::var("GREENTIC_TELEMETRY_CONFIG") {
        let trimmed = value.trim().to_string();
        if trimmed.is_empty() {
            return Ok(None);
        }
        return Ok(Some((trimmed, TelemetrySource::Env)));
    }

    if let Ok(file_path) = env::var("GREENTIC_TELEMETRY_CONFIG_FILE") {
        let path = PathBuf::from(&file_path);
        let contents = fs::read_to_string(&path)
            .with_context(|| format!("failed to read telemetry config file {file_path}"))?;
        let trimmed = contents.trim().to_string();
        if trimmed.is_empty() {
            return Ok(None);
        }
        return Ok(Some((trimmed, TelemetrySource::File(path))));
    }

    Ok(None)
}
