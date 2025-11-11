# Terraform Scaffold

Infrastructure entrypoint for PR-INFRA-01. The layout mirrors the requested provider split:

```
infra/terraform/
  modules/
    aws/      # AWS App Runner + OIDC + OTLP collector endpoint
    gcp/      # Cloud Run + Secret Manager bindings + Workload Identity pool
    azure/    # Container Apps + Managed Identity + secrets wiring
  envs/
    dev/
      aws/terraform.tfvars
      gcp/terraform.tfvars
      azure/terraform.tfvars
    prod/
      aws/terraform.tfvars
      gcp/terraform.tfvars
      azure/terraform.tfvars
```

Each module expects a provider block from the root configuration and exposes `service_url`, `otel_endpoint`, and `oidc_identity` outputs so CI can publish telemetry + smoke-test URLs. The environment `terraform.tfvars` files provide sample values that match the defaults described in PR-INFRA-01.
