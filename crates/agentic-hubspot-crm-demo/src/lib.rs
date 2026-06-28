//! Metadata wrapper for the HubSpot CRM Agentic-Worker demo.
//!
//! All meaningful content lives in `build-answer.json` (pack overlay) and the
//! `demos/agentic-hubspot-crm-demo-*` answer files. This crate only exposes the
//! demo identity so the workspace can build and reference it uniformly.

/// Stable identifier for this demo (matches the pack id and bundle prefix).
pub const DEMO_NAME: &str = "agentic-hubspot-crm-demo";

/// Directory (relative to the crate root) that holds the built bundle.
#[must_use]
pub fn bundle_dir() -> &'static str {
    "bundle"
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn demo_name_is_stable() {
        assert_eq!(DEMO_NAME, "agentic-hubspot-crm-demo");
    }

    #[test]
    fn bundle_dir_is_bundle() {
        assert_eq!(bundle_dir(), "bundle");
    }
}
