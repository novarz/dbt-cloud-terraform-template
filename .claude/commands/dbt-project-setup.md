# dbt Cloud Project Setup

Sets up a complete dbt Cloud project end-to-end:
- Understands the business domain, data sources, and desired metrics
- Scaffolds the dbt project structure (models, sources, seeds, tests, Semantic Layer YAML)
- Generates and applies Terraform (connection, environments, jobs, Semantic Layer)
- Configures the dbt Cloud MCP server in `.mcp.json`

---

## Skills to invoke

This command relies on the following Claude Code dbt skills. Invoke them explicitly at the relevant phase instead of doing the work manually:

| Skill | When to use |
|---|---|
| `dbt:using-dbt-for-analytics-engineering` | Phase 2 — generating staging models, intermediate, marts, seeds, tests, and YAML configs |
| `dbt:building-dbt-semantic-layer` | Phase 2 — generating semantic model YAMLs, metrics, entities, measures, time spine |
| `dbt:configuring-dbt-mcp-server` | Phase 8 — creating and validating the `.mcp.json` configuration |
| `dbt:running-dbt-commands` | Any phase — if dbt CLI commands need to be run (compile, parse, test) |

Do not attempt to generate dbt models or Semantic Layer YAML without invoking the appropriate skill first.

---

## Phase 1 — Understand the project

Start by asking the user about the **business context** of the dbt project. This determines the scaffold structure, naming conventions, and Semantic Layer design.

Use `AskUserQuestion` to collect these in **two rounds**:

### Round 1 — Domain & scope

Ask these questions together (up to 4 at a time):

1. **Domain / theme**: What is the business domain of this project?
   - Options: Banking / Financial Services, Retail & E-commerce, SaaS / Product analytics, Marketing & Growth, Healthcare, Logistics & Supply chain, Custom (ask to describe)

2. **Project complexity**: What level of sophistication do you need?
   - **Starter** — 1–2 source systems, staging + marts, basic metrics
   - **Standard** — 3–5 source systems, multi-domain marts, Semantic Layer with key KPIs
   - **Advanced** — 5+ source systems, full dimensional model, rich Semantic Layer, unit tests, governance

3. **Data warehouse**: Which data warehouse will this project use?
   - **Snowflake** — user + password authentication
   - **BigQuery** — service account JSON authentication

4. **Team size**: Who will work on this project?
   - Solo analyst, Small team (2–5), Larger team (5+)

### Round 2 — Data & metrics

Ask these questions together:

1. **Data sources**: Which source systems will feed this project? (multiSelect)
   - Options: Internal warehouse tables, Salesforce, Stripe, Google Analytics / GA4, HubSpot, PostgreSQL / MySQL, Custom / Other

2. **Key business questions**: What are the 3–5 main questions this project should answer? (free text)

3. **Modeling preference**: How do you prefer to structure marts?
   - **Wide tables** — one big flat table per entity (easy for BI tools)
   - **Normalized** — fact + dimension tables (more flexible, more joins)
   - **Activity schema** — all events in one table + pivot (great for product analytics)

4. **Time spine granularity**: What is the finest time grain you need for metrics?
   - Daily, Hourly, Both

---

## Phase 2 — Generate dbt project scaffold

**Invoke `dbt:using-dbt-for-analytics-engineering`** to generate models, sources, seeds, and tests.
**Invoke `dbt:building-dbt-semantic-layer`** to generate Semantic Layer YAMLs.

Based on the answers, create the following structure (do not overwrite files that already exist):

```
models/
  staging/
    {source_1}/
      __{source_1}__sources.yml
      stg_{source_1}__{entity}.sql      (one per main entity)
    {source_2}/
      ...
  intermediate/                         (only if complexity = Standard or Advanced)
    int_{domain}_{logic}.sql
  marts/
    {domain}/
      {mart_name}.sql
      {mart_name}.yml                   (column descriptions and generic tests)
  semantic/
    _entities.yml
    _metrics.yml
    _time_spine.yml

seeds/
  {domain}__{reference_data}.csv        (one per relevant lookup / reference table)
  _schema.yml

tests/                                  (if complexity = Advanced)
  unit/
    test_{key_model}.yml

macros/
  .gitkeep

dbt_project.yml                         (if not already present)
```

### Content guidelines

- **Staging models**: `SELECT` with renamed/typed columns only. Use `{{ source() }}`. Add `_loaded_at` metadata column.
- **Intermediate models**: business logic joins, no aggregations. Use `{{ ref() }}`.
- **Mart models**: final aggregated tables. Grain comment at the top. Use `{{ ref() }}`.
- **Seeds**: realistic CSV reference data relevant to the domain. Include `_schema.yml` with `not_null` + `accepted_values` tests.
- **`dbt_project.yml`**: materializations — `staging` → view, `intermediate` → ephemeral, `marts` → table, `seeds` → table.
- **Semantic Layer YAMLs**: MetricFlow syntax (`semantic_models`, `metrics`, `entities`, `measures`, `dimensions`). Metric types: `simple`, `ratio`, or `derived`.
- **Tests**: `not_null` + `unique` on primary keys for all staging and mart models.

Domain examples:
- **Banking**: entities = accounts, transactions, customers; seeds = account_types, currencies, transaction_categories
- **E-commerce**: entities = orders, customers, products; seeds = product_categories, countries, payment_methods
- **SaaS**: entities = users, sessions, subscriptions; seeds = plan_types, feature_flags, regions
- **Marketing**: entities = campaigns, leads, conversions; seeds = channel_types, utm_sources, regions

After generating the scaffold, briefly summarise what was created and ask for confirmation before proceeding.

---

## Phase 3 — GitHub repository

### Step 1 — Detect GitHub identity

```bash
gh api user --jq '{login: .login, name: .name}'
gh org list
```

Ask the user only:
- Which owner? (authenticated user or one of their orgs)
- Public or private?

Use the current directory name as the repo name — do not ask.

### Step 2 — Create repo and push

> ⚠️ **This step MUST happen before Terraform.** dbt Cloud needs the repo to exist and have at least one commit on main so that jobs can run against the code. Terraform will also link the project to this repo.

```bash
gh repo create {owner}/{directory_name} --private   # or --public
git init
git add .
git commit -m "chore: initial dbt project scaffold"
git remote add origin git@github.com:{owner}/{directory_name}.git
git push -u origin main
```

Set `git_remote_url = "git@github.com:{owner}/{directory_name}.git"` for Terraform.

---

## Phase 4 — Collect infrastructure parameters

Check if `dbt-project.yaml` exists → read from it automatically. Otherwise ask interactively.

**First question — always ask this explicitly, even in config file mode if not present:**

> "What is the name of your dbt Cloud project?"

Use this as `project_name` throughout all Terraform resources and the service token name.

### Common parameters (always required)

#### dbt Cloud
| Variable | Description | Example |
|---|---|---|
| `project_name` | dbt Cloud project name | `diverger_fusion_banking` |
| `dbt_account_id` | dbt Cloud account ID | `530` |
| `dbt_host_url` | API host URL (with `/api`) | `https://pk455.eu1.dbt.com/api` |
| `dbt_token` | Account Admin service token (**sensitive**) | `dbtc_...` |

#### Project
| Variable | Description | Example |
|---|---|---|
| `dbt_version` | dbt version | `versionless` |

#### Auto-discover `github_installation_id`

Do not ask the user. Run:

```bash
curl -s \
  -H "Authorization: Token $TF_VAR_dbt_token" \
  "{dbt_host_url}/v3/accounts/{dbt_account_id}/github/installations/" \
  | jq '.data[] | {id: .id, login: .account.login}'
```

Match `login` to the GitHub org/user. If empty or error, ask the user.

#### Schemas / datasets
| Variable | Snowflake | BigQuery |
|---|---|---|
| `schema_prefix` | Snowflake schema prefix | BigQuery dataset prefix |
| `schema_development` | `dev` | `dev` |
| `schema_staging` | `staging` | `staging` |
| `schema_production` | `prod` | `prod` |

#### Jobs
| Variable | Default |
|---|---|
| `daily_job_schedule_hours` | `[6]` |

---

### Snowflake-specific parameters

Only collect these if the user chose **Snowflake**:

| Variable | Description |
|---|---|
| `snowflake_account` | Account identifier (e.g. `zna84829`) |
| `snowflake_database` | Database name |
| `snowflake_warehouse` | Virtual warehouse name |
| `snowflake_user` | Username |
| `snowflake_password` | Password (**sensitive** — `TF_VAR_snowflake_password`) |
| `snowflake_role` | Role (optional, leave blank for default) |

---

### BigQuery-specific parameters

Only collect these if the user chose **BigQuery**:

| Variable | Description |
|---|---|
| `bq_project_id` | GCP project ID (e.g. `my-gcp-project`) |
| `bq_location` | Dataset location (e.g. `EU`, `US`, `europe-west1`) |
| `bq_service_account_json` | Full contents of the service account JSON file (**sensitive** — `TF_VAR_bq_service_account_json`) |

Ask the user to paste the contents of their service account JSON, or provide the file path so you can read it with the Read tool.

---

## Phase 5 — Create Terraform files

Create `terraform/` with `providers.tf`, `variables.tf`, `terraform.tfvars`, `main.tf`, `outputs.tf`.

**`terraform/providers.tf`** is the same regardless of warehouse:
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

**`terraform/variables.tf`** — declare all variables for the chosen warehouse. Mark `dbt_token`, `snowflake_password` / `bq_service_account_json` as `sensitive = true`.

**`terraform/terraform.tfvars`** — non-sensitive values only.

---

### `terraform/main.tf` — Snowflake variant

Use this when the user chose **Snowflake**:

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

# ─── Global connection ────────────────────────────────────────────────────────

resource "dbtcloud_global_connection" "this" {
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

# ─── Credentials ─────────────────────────────────────────────────────────────

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
  connection_id = dbtcloud_global_connection.this.id
  depends_on    = [dbtcloud_repository.this]
}

resource "dbtcloud_environment" "staging" {
  project_id      = dbtcloud_project.this.id
  name            = "Staging"
  dbt_version     = var.dbt_version
  type            = "deployment"
  deployment_type = "staging"
  credential_id   = dbtcloud_snowflake_credential.staging.credential_id
  connection_id   = dbtcloud_global_connection.this.id
  depends_on      = [dbtcloud_repository.this]
}

resource "dbtcloud_environment" "production" {
  project_id      = dbtcloud_project.this.id
  name            = "Production"
  dbt_version     = var.dbt_version
  type            = "deployment"
  deployment_type = "production"
  credential_id   = dbtcloud_snowflake_credential.production.credential_id
  connection_id   = dbtcloud_global_connection.this.id
  depends_on      = [dbtcloud_repository.this]
}

# ─── Jobs ─────────────────────────────────────────────────────────────────────

resource "dbtcloud_job" "daily" {
  project_id     = dbtcloud_project.this.id
  environment_id = dbtcloud_environment.staging.environment_id
  name           = "Daily Build"
  execute_steps  = ["dbt build"]
  dbt_version    = var.dbt_version
  generate_docs  = true
  schedule_type  = "every_day"
  schedule_hours = var.daily_job_schedule_hours
  triggers = {
    github_webhook = false, git_provider_webhook = false, schedule = true, on_merge = false
  }
}

resource "dbtcloud_job" "daily_prod" {
  project_id     = dbtcloud_project.this.id
  environment_id = dbtcloud_environment.production.environment_id
  name           = "Daily Build (Production)"
  execute_steps  = ["dbt build"]
  dbt_version    = var.dbt_version
  generate_docs  = true
  schedule_type  = "every_day"
  schedule_hours = var.daily_job_schedule_hours
  triggers = {
    github_webhook = false, git_provider_webhook = false, schedule = true, on_merge = false
  }
}

resource "dbtcloud_job" "slim_ci" {
  project_id               = dbtcloud_project.this.id
  environment_id           = dbtcloud_environment.staging.environment_id
  name                     = "Slim CI"
  execute_steps            = ["dbt build --select state:modified+ --defer --state ./artifacts"]
  dbt_version              = var.dbt_version
  deferring_environment_id = dbtcloud_environment.staging.environment_id
  run_compare_changes      = true
  triggers = {
    github_webhook = true, git_provider_webhook = true, schedule = false, on_merge = false
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

---

### `terraform/main.tf` — BigQuery variant

Use this when the user chose **BigQuery**.

Before writing this file, invoke `dbt:fetching-dbt-docs` to retrieve the latest `dbtcloud_global_connection` BigQuery block attributes and `dbtcloud_bigquery_credential` schema from the provider docs — do not guess field names.

The structure follows the same pattern as Snowflake with these differences:

```hcl
# ─── Global connection ────────────────────────────────────────────────────────

resource "dbtcloud_global_connection" "this" {
  name = "BigQuery Terraform"

  bigquery = {
    gcp_project_id         = var.bq_project_id
    location               = var.bq_location
    use_latest_adapter     = true                 # bigquery_v1 — supports WIF, recommended for new projects
    # auth fields come from the service account JSON:
    auth_type              = "service_account"
    client_email           = jsondecode(var.bq_service_account_json).client_email
    private_key            = jsondecode(var.bq_service_account_json).private_key
    private_key_id         = jsondecode(var.bq_service_account_json).private_key_id
    token_uri              = jsondecode(var.bq_service_account_json).token_uri
    # verify remaining fields against provider docs before including
  }
}

# ─── Credentials (BigQuery uses datasets, not schemas) ────────────────────────

resource "dbtcloud_bigquery_credential" "development" {
  project_id = dbtcloud_project.this.id
  dataset    = "${var.schema_prefix}_${var.schema_development}"
  threads    = 4
}

resource "dbtcloud_bigquery_credential" "staging" {
  project_id = dbtcloud_project.this.id
  dataset    = "${var.schema_prefix}_${var.schema_staging}"
  threads    = 16
}

resource "dbtcloud_bigquery_credential" "production" {
  project_id = dbtcloud_project.this.id
  dataset    = "${var.schema_prefix}_${var.schema_production}"
  threads    = 16
}

# ─── Environments — same as Snowflake but referencing bigquery credentials ────

# (same dbtcloud_environment resources, credential_id from bigquery credentials)

# ─── Semantic Layer ───────────────────────────────────────────────────────────

# Use dbtcloud_bigquery_semantic_layer_credential instead of snowflake variant.
# Set adapter_version = "bigquery_v1" to match use_latest_adapter = true on the connection.
# Retrieve exact block schema from provider docs before writing.
```

For BigQuery, `TF_VAR_bq_service_account_json` replaces `TF_VAR_snowflake_password`.

---

### `terraform/outputs.tf`

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
  value     = dbtcloud_service_token.semantic_layer.token_string
  sensitive = true
}

output "semantic_layer_token_uid" {
  value = dbtcloud_service_token.semantic_layer.uid
}
```

---

## Phase 6 — Update .gitignore

```
.mcp.json
dbt-project.yaml
terraform/.terraform/
terraform/terraform.tfstate
terraform/terraform.tfstate.backup
terraform/.terraform.lock.hcl
```

---

## Phase 7 — Run Terraform

> ⚠️ Only run this after Phase 3 (code committed to main). Terraform links dbt Cloud to the repo and creates jobs that need existing code to run.

**Snowflake:**
```bash
export TF_VAR_dbt_token="..."
export TF_VAR_snowflake_password="..."
```

**BigQuery:**
```bash
export TF_VAR_dbt_token="..."
export TF_VAR_bq_service_account_json='{ ... }'   # full JSON content, single-quoted
```

Then:
```bash
cd terraform && terraform init && terraform apply -auto-approve
```

Capture: `project_id`, `production_environment_id`, `staging_environment_id`.

> **Expected:** `dbtcloud_semantic_layer_configuration` will fail with "No successful runs found" — this is normal. Continue to Phase 7b.

---

## Phase 7b — Activate the Semantic Layer

The Semantic Layer requires at least one successful job run in the Production environment. Do this automatically:

### Step 1 — Trigger the Production job

Get the job ID from terraform state:
```bash
terraform state show dbtcloud_job.daily_prod | grep "^ *id "
```

Trigger it using the dbt MCP tool `mcp__dbt__trigger_job_run` with:
- `job_id`: the ID from above
- `cause`: "Initial run to activate Semantic Layer"

### Step 2 — Wait for completion

Poll using `mcp__dbt__get_job_run_details` with the run ID returned. Check `is_complete` and `is_success`.

- If `is_success = true` → proceed to Step 3
- If `is_cancelled` or `is_error` → report the `status_message` to the user and stop. Common causes: missing BigQuery permissions (`BigQuery Data Editor` + `BigQuery Job User` roles on the service account), BigQuery API not enabled in GCP, or Snowflake credentials wrong.

### Step 3 — Re-run terraform apply

```bash
cd terraform && terraform apply -auto-approve
```

This will now create `dbtcloud_semantic_layer_configuration` successfully.

---

## Phase 8 — Configure dbt Cloud MCP server

**Invoke `dbt:configuring-dbt-mcp-server`** to generate and validate the `.mcp.json`.

MCP host URL — account-prefixed format **without** `/api`:
- Example: `https://pk455.eu1.dbt.com` (not `https://pk455.eu1.dbt.com/api`)

```json
{
  "mcpServers": {
    "dbt": {
      "command": "uvx",
      "args": ["dbt-mcp"],
      "env": {
        "DBT_HOST": "<host_without_api>",
        "DBT_TOKEN": "<dbt_token>",
        "DBT_ACCOUNT_ID": "<dbt_account_id>",
        "DBT_PROJECT_ID": "<project_id>",
        "DBT_ENVIRONMENT_ID": "<production_environment_id>"
      }
    }
  }
}
```

---

## Phase 9 — Done

Summarise what was created:
- 📁 dbt project scaffold (models, seeds, sources, Semantic Layer YAMLs)
- ⚙️ Terraform resources applied (project, environments, jobs, Semantic Layer)
- 🔌 `.mcp.json` configured with dbt Cloud MCP

Reminders:
- 🔁 Restart Claude Code (`claude --continue` or reopen) to load the new MCP server.

---

## Notes

- Provider v1.8+ required for all Semantic Layer resources.
- `dbt_version` drift (`versionless` → `latest`) is benign, safe to ignore.
- `github_installation_id` is per GitHub org, not per project.
- For BigQuery: always fetch current provider docs before generating the connection block — field names differ from the Snowflake block.
- Sensitive files gitignored: `.mcp.json`, `dbt-project.yaml`, `terraform/terraform.tfstate`.
- **`dbt deps` is NOT a valid execute_step in dbt Cloud jobs** — dbt Cloud runs `dbt deps` automatically before any job. Never include it in `execute_steps`.
