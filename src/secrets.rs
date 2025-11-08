use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::Command;

use anyhow::{Context, Result, anyhow};

/// Resolve secrets either from environment, greentic-secrets CLI, or files.
pub fn read(name: &str) -> Result<String> {
    if let Ok(value) = env::var(name) {
        if !value.trim().is_empty() {
            return Ok(value);
        }
    }

    if let Some(value) = read_from_dir(name)? {
        return Ok(value);
    }

    if let Some(value) = read_via_cli(name)? {
        return Ok(value);
    }

    Err(anyhow!(
        "secret {name} not found; set env, GREENTIC_SECRETS_DIR/{name}, or provide greentic-secrets CLI"
    ))
}

fn read_from_dir(name: &str) -> Result<Option<String>> {
    let dir = match env::var("GREENTIC_SECRETS_DIR")
        .ok()
        .filter(|s| !s.is_empty())
    {
        Some(dir) => dir,
        None => return Ok(None),
    };

    let mut path = PathBuf::from(dir);
    path.push(name);
    if !path.exists() {
        return Ok(None);
    }

    let contents = fs::read_to_string(&path)
        .with_context(|| format!("failed reading secret file {path:?}"))?;
    Ok(Some(contents.trim().to_string()))
}

fn read_via_cli(name: &str) -> Result<Option<String>> {
    let cli = env::var("GREENTIC_SECRETS_CLI").unwrap_or_else(|_| "greentic-secrets".into());
    let output = Command::new(cli).arg("read").arg(name).output();

    let output = match output {
        Ok(output) => output,
        Err(_) => return Ok(None),
    };

    if !output.status.success() {
        return Err(anyhow!(
            "greentic-secrets read {name} failed: {}",
            String::from_utf8_lossy(&output.stderr)
        ));
    }

    let value = String::from_utf8(output.stdout)
        .map_err(|err| anyhow!("secret {name} is not utf8: {err}"))?;
    Ok(Some(value.trim().to_string()))
}
