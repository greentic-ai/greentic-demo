variable "project" {
  description = "GCP project id"
  type        = string
}

variable "region" {
  description = "Primary region"
  type        = string
}

variable "environment" {
  description = "Environment label"
  type        = string
}

variable "image" {
  description = "Container image hosted in Artifact Registry or GCR"
  type        = string
}

variable "pack_index_url" { type = string }
variable "pack_cache_dir" { type = string }
variable "pack_public_key" { type = string, nullable = true, default = null }
variable "secrets_backend" { type = string }
variable "tenant_resolver" { type = string }
variable "pack_refresh_interval" { type = string }
variable "telemetry_endpoint" { type = string }
variable "otel_service_name" { type = string }
variable "secrets" { type = list(string), default = [] }
