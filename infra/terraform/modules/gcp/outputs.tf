output "service_url" {
  description = "HTTPS endpoint for Cloud Run"
  value       = google_cloud_run_service.runner.status[0].url
}

output "otel_endpoint" {
  description = "Forwarded OTLP endpoint"
  value       = var.telemetry_endpoint
}

output "workload_identity_provider" {
  description = "Full resource name for GitHub OIDC provider"
  value       = google_iam_workload_identity_pool_provider.github.name
}
