terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "runner" {
  source                = "../../modules/azure"
  project               = var.project
  environment           = var.environment
  location              = var.location
  resource_group        = var.resource_group
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
