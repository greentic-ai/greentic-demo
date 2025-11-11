# Deploying greentic-demo

This repository ships a Terraform scaffold plus a reusable GitHub Actions workflow that builds the container image, applies infrastructure for AWS/GCP/Azure, and smoke-tests `/healthz`. Follow the steps below to enable it end to end.

## 1. Prepare cloud identities

Populate GitHub **Repository Variables** (or organization-wide variables) with the ARNs/IDs that the workflow expects:

### AWS

| Variable | Description |
| --- | --- |
| `AWS_REGION` | Shared region for App Runner + ECR (default `us-east-1` if unset) |
| `AWS_DEV_ROLE_ARN` | IAM role ARN that GitHub Actions assumes for dev deployments |
| `AWS_PROD_ROLE_ARN` | IAM role ARN used for prod deployments |

The IAM roles must trust `token.actions.githubusercontent.com` (as modeled in `infra/terraform/modules/aws`). Attach policies allowing ECR pushes, App Runner deployments, Secrets Manager, and CloudWatch Logs.

### GCP

| Variable | Description |
| --- | --- |
| `GCP_DEV_WORKLOAD_IDENTITY_PROVIDER` | Full resource name of the Workload Identity Provider for dev |
| `GCP_DEV_SERVICE_ACCOUNT` | Email of the dev service account |
| `GCP_PROD_WORKLOAD_IDENTITY_PROVIDER` | WIP name for prod |
| `GCP_PROD_SERVICE_ACCOUNT` | Email of the prod service account |

Grant each service account the required Cloud Run / Artifact Registry / Secret Manager roles.

### Azure

| Variable | Description |
| --- | --- |
| `AZURE_DEV_CLIENT_ID` / `AZURE_PROD_CLIENT_ID` | App registration (federated identity) client IDs |
| `AZURE_DEV_TENANT_ID` / `AZURE_PROD_TENANT_ID` | Directory tenant IDs |
| `AZURE_DEV_SUBSCRIPTION_ID` / `AZURE_PROD_SUBSCRIPTION_ID` | Subscription IDs that host Container Apps |

Each client ID must have a federated credential that trusts GitHub Actions (the Terraform module creates one when run manually, but you still need to supply the IDs).

## 2. Customize Terraform vars

Edit the sample `terraform.tfvars` under `infra/terraform/envs/{dev,prod}/{provider}/` to reflect your pack index URL, cache path, telemetry collector endpoint, and secret names. The GitHub workflow passes the freshly-built image via `-var image=...`, so you only need to manage static inputs here. Locally, keep `PACKS_DIR` (from `.env`) pointed at the directory that contains all tenant `bindings.yaml` files so the runner host can map tenants to bindings.

For ad-hoc local plans, run:

```bash
cd infra/terraform/envs/aws
terraform init
terraform plan -var-file=../dev/aws/terraform.tfvars -var "image=ghcr.io/<org>/greentic-demo:<tag>"
```

Repeat for `gcp` and `azure` as needed.

## 3. Run the Deploy workflow

Trigger **Actions → Deploy → Run workflow** and choose which providers/environments to target (comma-separated lists). The workflow will:

1. Build & push `ghcr.io/${repo}:${sha}` and `:latest` using the Dockerfile.
2. For each selected matrix entry, assume cloud credentials via OIDC.
3. Execute `terraform apply` with the matching `terraform.tfvars` file and injected image.
4. Capture the `service_url` + `otel_endpoint` outputs.
5. `curl -fsS $service_url/healthz` as a smoke check and summarize the results in the workflow run.

## 4. Verify telemetry and secrets

Bring your own OTLP collector endpoint (see `telemetry_endpoint` vars) and ensure the referenced secrets exist in each provider’s store. The current shim reads `PACK_PUBLIC_KEY`, `SECRETS_BACKEND`, and `TENANT_RESOLVER` from env, so keep the Terraform variables in sync with your deployment expectations.

## 5. Keeping environments in sync

- Commit changes to `infra/terraform` alongside code so Terraform state stays consistent.
- Rotate credentials by updating the referenced GitHub variables — no workflow edits required.
- For temporary smoke deployments, run `terraform destroy` manually in the appropriate env folder.
