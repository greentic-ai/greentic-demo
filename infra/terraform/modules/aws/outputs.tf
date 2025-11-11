output "service_url" {
  description = "Public HTTPS endpoint for the runner"
  value       = aws_apprunner_service.runner.service_url
}

output "otel_endpoint" {
  description = "Endpoint that collectors should scrape"
  value       = var.telemetry_endpoint
}

output "oidc_role_arn" {
  description = "IAM role assumed via GitHub OIDC"
  value       = aws_iam_role.ci.arn
}
