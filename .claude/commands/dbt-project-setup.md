# dbt Cloud Project Setup

Sets up a complete dbt Cloud project end-to-end:
- Generates Terraform code (Snowflake connection, environments, jobs, Semantic Layer)
- Provisions the project on dbt Cloud Platform via `terraform apply`
- Configures the dbt Cloud MCP server in `.mcp.json`

---

## Mode detection

First, check if a `dbt-project.yaml` file exists in the current directory.

- **If it exists** → read all parameters from it and proceed automatically without asking questions.
- **If it does not exist** → enter interactive mode: use `AskUserQuestion` to collect the parameters below in groups of 3–4 questions maximum at a time.

---

## Parameters to collect

### dbt Cloud
| Variable | Description | Example |
|---|---|---|
| `dbt_account_id` | dbt Cloud account ID | `530` |
| `dbt_host_url` | API host URL | `https://emea.dbt.com/api` |
| `dbt_token` | Account Admin service token (**sensitive**) | `dbtc_...` |

### Project
| Variable | Description | Example |
|---|---|---|
| `project_name` | Name of the dbt Cloud project | `my_project` |
| `git_remote_url` | SSH URL of the GitHub repo | `git@github.com:org/repo.git` |
| `github_installation_id` | GitHub App installation ID for the org | `103071669` |
| `dbt_version` | dbt version | `versionless` |

### Snowflake
| Variable | Description | Example |
|---|---|---|
| `snowflake_account` | Snowflake account identifier | `zna84829` |
| `snowflake_database` | Snowflake database | `Analytics` |
| `snowflake_warehouse` | Snowflake warehouse | `transforming` |
| `snowflake_user` | Snowflake user | `MY_USER` |
| `snowflake_password` | Snowflake password (**sensitive**) | — |
| `snowflake_role` | Snowflake role (optional, leave blank for default) | `""` |

### Schemas
| Variable | Description | Default |
|---|---|---|
| `schema_prefix` | Prefix for all schemas | `dbt_myproject` |
| `schema_development` | Development schema suffix | `dev` |
| `schema_staging` | Staging schema suffix | `staging` |
| `schema_production` | Production schema suffix | `prod` |

### Jobs
| Variable | Description | Default |
|---|---|---|
| `daily_job_schedule_hours` | UTC hours for daily builds | `[6]` |

---

## Execution steps

### Step 1 — Create Terraform files

Create a `terraform/` directory in the current working directory with these files, filled with the collected values:

**`terraform/providers.tf`**
```hcl
terraform {
  required_providers {
    dbtcloud = {
      source  = "dbt-labs/dbtcloud"
      version = "~> 1.8"
    }
  }
}

provider "dbtcloud" {
  token      = var.dbt_token
  account_id = var.dbt_account_id
  host_url   = var.dbt_host_url
}
```

**`terraform/variables.tf`** — declare all variables from the parameters table above. Mark `dbt_token` and `snowflake_password` as `sensitive = true`.

**`terraform/terraform.tfvars`** — write all non-sensitive values only. Never write `dbt_token` or `snowflake_password` here.

**`terraform/main.tf`** — use the full resource structure below:

```hcl
# ─── Project ──────────────────────────────────────────────────────────────────

resource "dbtcloud_project" "this" {
  name = var.project_name
}

# ─── Repository ───────────────────────────────────────────────────────────────

resource "dbtcloud_repository" "this" {
  project_id             = dbtcloud_project.this.id
  remote_url             = var.git_remote_url
  git_clone_strategy     = var.git_clone_strategy
  github_installation_id = var.github_installation_id
}

# ─── Global connection (Snowflake) ────────────────────────────────────────────

resource "dbtcloud_global_connection" "snowflake" {
  name = "Snowflake Terraform"

  snowflake = {
    account   = var.snowflake_account
    database  = var.snowflake_database
    warehouse = var.snowflake_warehouse
    role      = var.snowflake_role != "" ? var.snowflake_role : null
  }
}

# ─── Link repository to project ──────────────────────────────────────────────

resource "dbtcloud_project_repository" "this" {
  project_id    = dbtcloud_project.this.id
  repository_id = dbtcloud_repository.this.repository_id
}

# ─── Snowflake credentials ────────────────────────────────────────────────────

resource "dbtcloud_snowflake_credential" "development" {
  project_id  = dbtcloud_project.this.id
  auth_type   = "password"
  num_threads = 4
  user        = var.snowflake_user
  password    = var.snowflake_password
  schema      = "${var.schema_prefix}_${var.schema_development}"
}

resource "dbtcloud_snowflake_credential" "staging" {
  project_id  = dbtcloud_project.this.id
  auth_type   = "password"
  num_threads = 16
  user        = var.snowflake_user
  password    = var.snowflake_password
  schema      = "${var.schema_prefix}_${var.schema_staging}"
}

resource "dbtcloud_snowflake_credential" "production" {
  project_id  = dbtcloud_project.this.id
  auth_type   = "password"
  num_threads = 16
  user        = var.snowflake_user
  password    = var.snowflake_password
  schema      = "${var.schema_prefix}_${var.schema_production}"
}

# ─── Environments ─────────────────────────────────────────────────────────────

resource "dbtcloud_environment" "development" {
  project_id    = dbtcloud_project.this.id
  name          = "Development"
  dbt_version   = var.dbt_version
  type          = "development"
  credential_id = dbtcloud_snowflake_credential.development.credential_id
  connection_id = dbtcloud_global_connection.snowflake.id

  depends_on = [dbtcloud_repository.this]
}

resource "dbtcloud_environment" "staging" {
  project_id      = dbtcloud_project.this.id
  name            = "Staging"
  dbt_version     = var.dbt_version
  type            = "deployment"
  deployment_type = "staging"
  credential_id   = dbtcloud_snowflake_credential.staging.credential_id
  connection_id   = dbtcloud_global_connection.snowflake.id

  depends_on = [dbtcloud_repository.this]
}

resource "dbtcloud_environment" "production" {
  project_id      = dbtcloud_project.this.id
  name            = "Production"
  dbt_version     = var.dbt_version
  type            = "deployment"
  deployment_type = "production"
  credential_id   = dbtcloud_snowflake_credential.production.credential_id
  connection_id   = dbtcloud_global_connection.snowflake.id

  depends_on = [dbtcloud_repository.this]
}

# ─── Job: Daily Build (Staging) ───────────────────────────────────────────────

resource "dbtcloud_job" "daily" {
  project_id     = dbtcloud_project.this.id
  environment_id = dbtcloud_environment.staging.environment_id
  name           = "Daily Build"
  execute_steps  = ["dbt deps", "dbt build", "dbt docs generate"]
  dbt_version    = var.dbt_version
  generate_docs  = true

  schedule_type  = "every_day"
  schedule_hours = var.daily_job_schedule_hours

  triggers = {
    github_webhook       = false
    git_provider_webhook = false
    schedule             = true
    on_merge             = false
  }
}

# ─── Job: Daily Build (Production) ────────────────────────────────────────────

resource "dbtcloud_job" "daily_prod" {
  project_id     = dbtcloud_project.this.id
  environment_id = dbtcloud_environment.production.environment_id
  name           = "Daily Build (Production)"
  execute_steps  = ["dbt deps", "dbt build", "dbt docs generate"]
  dbt_version    = var.dbt_version
  generate_docs  = true

  schedule_type  = "every_day"
  schedule_hours = var.daily_job_schedule_hours

  triggers = {
    github_webhook       = false
    git_provider_webhook = false
    schedule             = true
    on_merge             = false
  }
}

# ─── Job: Slim CI ─────────────────────────────────────────────────────────────

resource "dbtcloud_job" "slim_ci" {
  project_id     = dbtcloud_project.this.id
  environment_id = dbtcloud_environment.staging.environment_id
  name           = "Slim CI"
  execute_steps  = ["dbt deps", "dbt build --select state:modified+ --defer --state ./artifacts"]
  dbt_version    = var.dbt_version

  deferring_environment_id = dbtcloud_environment.staging.environment_id
  run_compare_changes      = true

  triggers = {
    github_webhook       = true
    git_provider_webhook = true
    schedule             = false
    on_merge             = false
  }
}

# ─── Semantic Layer ───────────────────────────────────────────────────────────

resource "dbtcloud_semantic_layer_configuration" "this" {
  project_id     = dbtcloud_project.this.id
  environment_id = dbtcloud_environment.production.environment_id
}

resource "dbtcloud_snowflake_semantic_layer_credential" "this" {
  configuration = {
    project_id      = dbtcloud_project.this.id
    name            = "Snowflake SL Credential"
    adapter_version = "snowflake_v0"
  }

  credential = {
    project_id  = dbtcloud_project.this.id
    auth_type   = "password"
    num_threads = 8
    user        = var.snowflake_user
    password    = var.snowflake_password
    schema      = "${var.schema_prefix}_${var.schema_production}"
    database    = var.snowflake_database
  }
}

resource "dbtcloud_service_token" "semantic_layer" {
  name = "${var.project_name}_semantic_layer"

  service_token_permissions {
    permission_set = "semantic_layer_only"
    project_id     = dbtcloud_project.this.id
    all_projects   = false
  }

  service_token_permissions {
    permission_set = "metadata_only"
    project_id     = dbtcloud_project.this.id
    all_projects   = false
  }
}

resource "dbtcloud_semantic_layer_credential_service_token_mapping" "this" {
  project_id                   = dbtcloud_project.this.id
  semantic_layer_credential_id = dbtcloud_snowflake_semantic_layer_credential.this.id
  service_token_id             = dbtcloud_service_token.semantic_layer.id
}
```

**`terraform/outputs.tf`**
```hcl
output "project_id" {
  value = dbtcloud_project.this.id
}

output "production_environment_id" {
  value = dbtcloud_environment.production.environment_id
}

output "staging_environment_id" {
  value = dbtcloud_environment.staging.environment_id
}

output "semantic_layer_token" {
  description = "Service token for the Semantic Layer (only shown on first apply)"
  value       = dbtcloud_service_token.semantic_layer.token_string
  sensitive   = true
}

output "semantic_layer_token_uid" {
  value = dbtcloud_service_token.semantic_layer.uid
}
```

### Step 2 — Update .gitignore

Ensure the following entries exist in `.gitignore` at the project root:
```
.mcp.json
terraform/.terraform/
terraform/terraform.tfstate
terraform/terraform.tfstate.backup
terraform/.terraform.lock.hcl
```

### Step 3 — Set sensitive env vars

Before running Terraform, set:
```bash
export TF_VAR_dbt_token="<dbt_token>"
export TF_VAR_snowflake_password="<snowflake_password>"
```

### Step 4 — Run Terraform

```bash
cd terraform
terraform init
terraform apply -auto-approve
```

Capture the outputs after apply:
- `project_id`
- `production_environment_id`
- `staging_environment_id`

### Step 5 — Configure dbt Cloud MCP server

**Important:** The dbt Cloud MCP host URL does NOT include `/api`. 
URL format: `https://{prefix}.dbt.com` or `https://emea.dbt.com` depending on region.

Create `.mcp.json` at the project root with the dbt token hardcoded (the file is gitignored):

```json
{
  "mcpServers": {
    "dbt": {
      "command": "uvx",
      "args": ["dbt-mcp"],
      "env": {
        "DBT_HOST": "<dbt_host_without_api_suffix>",
        "DBT_TOKEN": "<dbt_token>",
        "DBT_ACCOUNT_ID": "<dbt_account_id>",
        "DBT_PROJECT_ID": "<project_id_from_terraform_output>",
        "DBT_ENVIRONMENT_ID": "<production_environment_id_from_terraform_output>"
      }
    }
  }
}
```

### Step 6 — Done

Inform the user:
- ✅ Terraform resources created
- ✅ `.mcp.json` configured with dbt Cloud MCP
- ⚠️ The Semantic Layer configuration requires a successful job run in Production before it activates. Trigger "Daily Build (Production)" manually in dbt Cloud to complete the setup.
- 🔁 Restart Claude Code (or run `claude --continue`) to load the new MCP server.

---

## Notes

- `dbtcloud_semantic_layer_configuration` will fail if no successful run exists in the production environment. If it fails, trigger the production job manually and re-run `terraform apply`.
- `dbt_version` drift: the provider may show benign updates from `versionless` to `latest` on subsequent applies — this is safe to ignore.
- `github_installation_id` is fixed per GitHub org. For the `novarz` org it is `103071669`.
