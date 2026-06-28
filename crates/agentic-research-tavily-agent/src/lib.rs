//! Marker crate for the standalone `agentic-research-tavily-agent` pack.
//!
//! The deliverable is the built `.gtpack` (kind `dw-application`) carrying the
//! `demo_assistant` Agentic Worker, its `secrets-policy.json`, and the Tavily
//! tool extension declaration. The pack source lives in `pack.yaml` +
//! `pack.extensions.json`; this crate exists so the pack participates in the
//! workspace and ships a README with publish/install steps.

/// Pack id of the standalone agent pack.
pub const PACK_ID: &str = "agentic-research-tavily-agent";

/// The agent id exposed to flows as `dw.agent { operation: demo_assistant }`.
pub const AGENT_ID: &str = "demo_assistant";
