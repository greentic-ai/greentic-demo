//! Runner shim that either re-exports the upstream API or falls back to a stub.

#[cfg(feature = "use-runner-api")]
pub use greentic_runner_host::{RunnerConfig, run};

#[cfg(all(not(feature = "use-runner-api"), feature = "runner-shim"))]
mod shim;

#[cfg(all(not(feature = "use-runner-api"), feature = "runner-shim"))]
pub use shim::{RunnerConfig, run};

#[cfg(not(any(feature = "use-runner-api", feature = "runner-shim")))]
compile_error!("Enable either the use-runner-api or runner-shim feature");
