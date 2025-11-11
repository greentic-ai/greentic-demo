terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

module "runner" {
  source                = "../../modules/gcp"
  project               = var.project
  environment           = var.environment
  region                = var.region
  image                 = var.image
  pack_index_url        = var.pack_index_url
  pack_cache_dir        = var.pack_cache_dir
  pack_public_key       = var.pack_public_key
  secrets_backend       = var.secrets_backend
  tenant_resolver       = var.tenant_resolver
  pack_refresh_interval = var.pack_refresh_interval
  telemetry_endpoint    = var.telemetry_endpoint
  otel_service_name     = var.otel_service_name
  secrets               = var.secrets
}
