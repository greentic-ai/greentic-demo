use std::sync::Arc;

use anyhow::{Context, Result};
use async_nats::{AuthError, Client, ConnectOptions, Message};
use futures::StreamExt;
use tokio::task::JoinSet;

use crate::SubjectConfig;
use crate::config::{AppConfig, Mode, NatsAuth};
use crate::health::HealthMonitor;
use crate::runner_bridge::RunnerBridge;
use crate::types::Activity;

pub struct NatsBridge {
    client: Client,
    runner: RunnerBridge,
    mode: Mode,
    tenants: Vec<String>,
    subjects: SubjectConfig,
    health: HealthMonitor,
}

impl NatsBridge {
    pub async fn connect(
        config: &AppConfig,
        runner: RunnerBridge,
        tenants: Vec<String>,
        health: HealthMonitor,
    ) -> Result<Self> {
        let client = connect_client(&config.nats).await?;
        tracing::info!(
            url = %config.nats.url,
            mode = ?config.mode,
            tenants = tenants.len(),
            "connected to NATS"
        );

        Ok(Self {
            client,
            runner,
            mode: config.mode.clone(),
            tenants,
            subjects: config.subjects.clone(),
            health,
        })
    }

    pub async fn run(self) -> Result<()> {
        if self.tenants.is_empty() {
            tracing::warn!("no packs registered; bridge idle");
        }

        tracing::info!(mode = ?self.mode, "starting NATS bridge loop");

        let mut join_set = JoinSet::new();
        for tenant in &self.tenants {
            let subject = self.subjects.ingress_subject(tenant);
            let mut subscription = self
                .client
                .subscribe(subject.clone())
                .await
                .with_context(|| format!("failed to subscribe to {subject}"))?;
            tracing::info!(tenant = %tenant, subject = %subject, "ingress subscription active");
            let runner = self.runner.clone();
            let client = self.client.clone();
            let egress_subject = self.subjects.egress_subject(tenant);
            let tenant_name = tenant.clone();
            let health = self.health.clone();

            join_set.spawn(async move {
                let tenant = tenant_name;
                while let Some(message) = subscription.next().await {
                    if let Err(err) = process_message(
                        &tenant,
                        &egress_subject,
                        &runner,
                        &client,
                        &health,
                        message,
                    )
                    .await
                    {
                        tracing::error!(tenant = %tenant, error = %err, "failed to process message");
                    }
                }
                Ok::<(), anyhow::Error>(())
            });
        }

        let shutdown = tokio::signal::ctrl_c();
        tokio::pin!(shutdown);
        loop {
            tokio::select! {
                _ = &mut shutdown => {
                    tracing::info!("shutdown signal received; draining subscriptions");
                    break;
                }
                Some(join_result) = join_set.join_next() => {
                    match join_result {
                        Ok(Ok(())) => continue,
                        Ok(Err(err)) => return Err(err),
                        Err(err) => return Err(err.into()),
                    }
                }
            }
        }

        while let Some(join_result) = join_set.join_next().await {
            match join_result {
                Ok(Ok(())) => continue,
                Ok(Err(err)) => return Err(err),
                Err(err) => return Err(err.into()),
            }
        }

        Ok(())
    }
}

async fn process_message(
    tenant: &str,
    egress: &str,
    runner: &RunnerBridge,
    client: &Client,
    health: &HealthMonitor,
    message: Message,
) -> Result<()> {
    let activity: Activity = match serde_json::from_slice(message.payload.as_ref()) {
        Ok(val) => val,
        Err(err) => {
            tracing::warn!(tenant = %tenant, error = %err, "invalid activity payload");
            health.record_failure(tenant);
            return Ok(());
        }
    };

    health.record_ingress(tenant);

    let activity_id = activity
        .activity_id()
        .map(|id| id.to_string())
        .unwrap_or_else(|| "unknown".into());
    tracing::debug!(tenant = %tenant, kind = "ingress", activity_id = %activity_id, "activity received");

    match runner.handle_activity(tenant, activity).await {
        Ok(responses) => {
            for response in responses {
                let response_id = response
                    .activity_id()
                    .map(|id| id.to_string())
                    .unwrap_or_else(|| "unknown".into());
                let payload = serde_json::to_vec(&response)?;
                client
                    .publish(egress.to_string(), payload.into())
                    .await
                    .with_context(|| format!("failed to publish to {egress}"))?;
                tracing::debug!(
                    tenant = %tenant,
                    kind = "egress",
                    activity_id = %response_id,
                    "activity published"
                );
                health.record_egress(tenant);
            }
        }
        Err(err) => {
            tracing::error!(tenant = %tenant, activity_id = %activity_id, error = %err, "runner error");
            health.record_failure(tenant);
        }
    }

    Ok(())
}

async fn connect_client(config: &crate::config::NatsConfig) -> Result<Client> {
    let options = match &config.auth {
        NatsAuth::None => ConnectOptions::new(),
        NatsAuth::Jwt { jwt, seed } => {
            let seed = Arc::new(seed.clone());
            ConnectOptions::new().jwt(jwt.clone(), move |nonce: Vec<u8>| {
                let seed = seed.clone();
                async move {
                    let key_pair = nkeys::KeyPair::from_seed(&seed).map_err(AuthError::new)?;
                    key_pair.sign(&nonce).map_err(AuthError::new)
                }
            })
        }
    };

    options
        .name("greentic-demo")
        .connect(&config.url)
        .await
        .with_context(|| format!("failed to connect to {}", config.url))
}
