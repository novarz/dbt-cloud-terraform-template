# dbt Cloud Terraform Template

Terraform template to provision a **dbt Cloud project** with Snowflake, GitHub App integration, environments, and CI/CD jobs.

## What gets created

| Resource | Details |
|----------|---------|
| `dbtcloud_project` | The dbt Cloud project |
| `dbtcloud_global_connection` | Snowflake connection |
| `dbtcloud_repository` | GitHub repo via GitHub App |
| `dbtcloud_project_repository` | Links repo to project |
| `dbtcloud_snowflake_credential` x2 | Dev + Staging credentials |
| `dbtcloud_environment` x2 | Development + Staging |
| `dbtcloud_job` Daily Build | `dbt build` on a schedule |
| `dbtcloud_job` Slim CI | `dbt build --select state:modified+` on PRs with compare changes |

## Usage

### 1. Fill in variables

Edit `terraform/terraform.tfvars` and replace all `REPLACE` placeholders.

See `docs/` for help with specific values:
- [`docs/regions.md`](docs/regions.md) — dbt Cloud host URLs by region
- [`docs/find-github-installation-id.md`](docs/find-github-installation-id.md) — how to get the GitHub App installation ID

### 2. Set sensitive variables as env vars

```bash
export TF_VAR_dbt_token="dbtc_..."
export TF_VAR_snowflake_password="..."
```

### 3. Run Terraform

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Reusing for multiple projects

Each project only needs its own `terraform.tfvars`. The `main.tf`, `variables.tf`, and `providers.tf` are fully reusable.

## Provider

Uses [`dbt-labs/dbtcloud`](https://registry.terraform.io/providers/dbt-labs/dbtcloud/latest) ~> 0.3.

## Known gotchas

- `dbtcloud_project_repository` is a **separate resource** — without it, `repository_id` is null on the project even if the repo exists.
- Use `dbtcloud_global_connection`, not the deprecated `dbtcloud_connection`.
- CI jobs must use `deferring_environment_id`, not `deferring_job_id`.
- The `host_url` must include `/api` (e.g. `https://emea.dbt.com/api`).
- Git remote URL must be SSH format: `git@github.com:org/repo.git`.
