use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Duration, Instant};

use tokio::task::JoinHandle;
use tokio::time;

use parking_lot::Mutex;

#[derive(Clone)]
pub struct HealthMonitor {
    state: Arc<Mutex<HashMap<String, TenantHealth>>>,
    interval: Duration,
}

#[derive(Default, Debug, Clone)]
struct TenantHealth {
    last_ingress: Option<Instant>,
    last_egress: Option<Instant>,
    ingress_count: u64,
    egress_count: u64,
    error_count: u64,
}

pub struct HealthHandle {
    task: JoinHandle<()>,
}

impl HealthMonitor {
    pub fn new(report_interval: Duration) -> Self {
        Self {
            state: Arc::new(Mutex::new(HashMap::new())),
            interval: report_interval,
        }
    }

    pub fn spawn_reporter(&self) -> HealthHandle {
        let state = Arc::clone(&self.state);
        let interval = self.interval;
        let task = tokio::spawn(async move {
            let mut ticker = time::interval(interval.max(Duration::from_secs(5)));
            loop {
                ticker.tick().await;
                let snapshot = state.lock().clone();
                if snapshot.is_empty() {
                    tracing::info!("health: no tenants registered yet");
                    continue;
                }
                for (tenant, health) in snapshot {
                    tracing::info!(
                        tenant = %tenant,
                        ingress = health.ingress_count,
                        egress = health.egress_count,
                        errors = health.error_count,
                        last_ingress = ?health.last_ingress.map(|_| "recent"),
                        last_egress = ?health.last_egress.map(|_| "recent"),
                        "health summary"
                    );
                }
            }
        });
        HealthHandle { task }
    }

    pub fn record_ingress(&self, tenant: &str) {
        let mut guard = self.state.lock();
        let entry = guard.entry(tenant.to_string()).or_default();
        entry.ingress_count = entry.ingress_count.saturating_add(1);
        entry.last_ingress = Some(Instant::now());
    }

    pub fn record_egress(&self, tenant: &str) {
        let mut guard = self.state.lock();
        let entry = guard.entry(tenant.to_string()).or_default();
        entry.egress_count = entry.egress_count.saturating_add(1);
        entry.last_egress = Some(Instant::now());
    }

    pub fn record_failure(&self, tenant: &str) {
        let mut guard = self.state.lock();
        let entry = guard.entry(tenant.to_string()).or_default();
        entry.error_count = entry.error_count.saturating_add(1);
    }
}

impl Drop for HealthHandle {
    fn drop(&mut self) {
        self.task.abort();
    }
}
