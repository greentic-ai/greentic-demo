output "service_url" {
  value = module.runner.service_url
}

output "otel_endpoint" {
  value = module.runner.otel_endpoint
}

output "workload_identity_provider" {
  value = module.runner.workload_identity_provider
}
