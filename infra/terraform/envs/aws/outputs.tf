output "service_url" {
  value = module.runner.service_url
}

output "otel_endpoint" {
  value = module.runner.otel_endpoint
}

output "oidc_role_arn" {
  value = module.runner.oidc_role_arn
}
