output "service_url" {
  description = "Public FQDN for the Container App"
  value       = azurerm_container_app.runner.latest_revision_fqdn
}

output "otel_endpoint" {
  description = "OTLP endpoint configured for the app"
  value       = var.telemetry_endpoint
}

output "federated_identity_principal_id" {
  description = "Principal ID for the GitHub Actions federated credential"
  value       = azurerm_user_assigned_identity.ci.principal_id
}
