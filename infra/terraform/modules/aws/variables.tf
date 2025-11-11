variable "project" {
  description = "Short project slug (e.g. greentic-demo)"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev|prod)"
  type        = string
}

variable "region" {
  description = "AWS region for all resources"
  type        = string
}

variable "image" {
  description = "Full ECR image reference pushed by CI"
  type        = string
}

variable "pack_index_url" {
  description = "Pack index.json URL or path"
  type        = string
}

variable "pack_cache_dir" {
  description = "Directory mounted inside the container for cached packs"
  type        = string
}

variable "pack_public_key" {
  description = "Optional Ed25519 key for verifying signed packs"
  type        = string
  nullable    = true
  default     = null
}

variable "secrets_backend" {
  description = "Secrets backend hint (env|aws)"
  type        = string
}

variable "tenant_resolver" {
  description = "Tenant resolver strategy"
  type        = string
}

variable "pack_refresh_interval" {
  description = "Polling interval for pack hot reloads"
  type        = string
}

variable "telemetry_endpoint" {
  description = "OTLP collector endpoint"
  type        = string
}

variable "otel_service_name" {
  description = "Service name reported to OpenTelemetry"
  type        = string
}

variable "secrets" {
  description = "List of secrets to expose via AWS Secrets Manager"
  type        = list(string)
  default     = []
}
