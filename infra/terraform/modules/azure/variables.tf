variable "project" { type = string }
variable "environment" { type = string }
variable "location" { type = string }
variable "resource_group" { type = string }
variable "image" { type = string }
variable "pack_index_url" { type = string }
variable "pack_cache_dir" { type = string }
variable "pack_public_key" { type = string, nullable = true, default = null }
variable "secrets_backend" { type = string }
variable "tenant_resolver" { type = string }
variable "pack_refresh_interval" { type = string }
variable "telemetry_endpoint" { type = string }
variable "otel_service_name" { type = string }
variable "secrets" { type = list(string), default = [] }
