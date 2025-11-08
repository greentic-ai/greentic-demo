macro_rules! include_runner_src {
    ($path:literal) => {
        include!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/../../../greentic-runner/crates/host/src/",
            $path
        ));
    };
}

pub mod config {
    include_runner_src!("config.rs");
}

pub mod imports {
    include_runner_src!("imports/mod.rs");
}

pub mod pack {
    include_runner_src!("pack.rs");
}

pub mod telemetry;

pub mod verify {
    include_runner_src!("verify.rs");
}

pub mod runner_engine {
    include_runner_src!("runner/engine.rs");
}

pub use config::{
    FlowBinding, HostConfig, McpConfig, McpRetryConfig, RateLimits, SecretsPolicy, TimerBinding,
    WebhookPolicy,
};
pub use pack::{FlowDescriptor, PackRuntime};
pub use runner_engine::{FlowContext, FlowEngine, RetryConfig};
