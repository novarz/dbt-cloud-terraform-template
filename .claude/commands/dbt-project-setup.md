# dbt Cloud Project Setup

Sets up a complete dbt Cloud project end-to-end:
- Understands the business domain, data sources, and desired metrics
- Scaffolds the dbt project structure (models, sources, seeds, tests, Semantic Layer YAML)
- Generates and applies Terraform (Snowflake connection, environments, jobs, Semantic Layer)
- Configures the dbt Cloud MCP server in `.mcp.json`

---

## Skills to invoke

This command relies on the following Claude Code dbt skills. Invoke them explicitly at the relevant phase instead of doing the work manually:

| Skill | When to use |
|---|---|
| `dbt:using-dbt-for-analytics-engineering` | Phase 2 — generating staging models, intermediate, marts, seeds, tests, and YAML configs |
| `dbt:building-dbt-semantic-layer` | Phase 2 — generating semantic model YAMLs, metrics, entities, measures, time spine |
| `dbt:configuring-dbt-mcp-server` | Phase 7 — creating and validating the `.mcp.json` configuration |
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

3. **Data sources**: Which source systems will feed this project? (multiSelect)
   - Options: Snowflake (internal tables), Salesforce, Stripe, Google Analytics / GA4, HubSpot, PostgreSQL / MySQL, Custom / Other

4. **Team size**: Who will work on this project?
   - Solo analyst, Small team (2–5), Larger team (5+)

### Round 2 — Data & metrics

Ask these questions together:

1. **Key business questions**: What are the 3–5 main questions this project should answer? (free text — ask the user to list them)

2. **Primary grain / entities**: What are the main business entities? e.g. customers, orders, accounts, transactions, sessions, leads (free text)

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

Based on the answers, create the following structure in the current working directory (do not overwrite files that already exist):

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
      {mart_name}.sql                   (one per main business entity / KPI area)
      {mart_name}.yml                   (with column descriptions and generic tests)
  semantic/
    _entities.yml                       (entities for Semantic Layer)
    _metrics.yml                        (metrics derived from the business questions)
    _time_spine.yml                     (time spine at the chosen granularity)

seeds/
  {domain}__{reference_data}.csv        (one per relevant lookup / reference table)
  _schema.yml                           (column descriptions and tests for seeds)

tests/                                  (if complexity = Advanced)
  unit/
    test_{key_model}.yml

macros/
  .gitkeep

dbt_project.yml                         (if not already present)
```

### Content guidelines

- **Staging models**: `SELECT` with renamed/typed columns only. Use `{{ source('source_name', 'table_name') }}`. Add `_loaded_at` surrogate metadata column.
- **Intermediate models**: business logic joins, no aggregations. Use `{{ ref() }}`.
- **Mart models**: final aggregated tables. Grain comment at the top of each file. Use `{{ ref() }}`.
- **Seeds**: generate realistic CSV reference data relevant to the domain (e.g. country codes, currency codes, product categories, account types, status mappings). Include a `_schema.yml` with descriptions and `not_null` + `accepted_values` tests. Materialise seeds as `table`.
- **`dbt_project.yml`**: set `name`, `version`, materializations (`staging` → view, `intermediate` → ephemeral or view, `marts` → table, `seeds` → table).
- **Semantic Layer YAMLs**: generate stubs matching the business questions. Use MetricFlow syntax (`semantic_models`, `metrics`, `entities`, `measures`, `dimensions`). Metric types: `simple`, `ratio`, or `derived` as appropriate.
- **Tests**: at minimum, `not_null` + `unique` on primary keys for all staging and mart models.

Adapt the scaffold to the domain. For example:
- **Banking**: entities = accounts, transactions, customers; seeds = account_types, currencies, transaction_categories; metrics = balance, transaction_volume, churn_rate
- **E-commerce**: entities = orders, customers, products; seeds = product_categories, countries, payment_methods; metrics = GMV, AOV, retention, LTV
- **SaaS**: entities = users, sessions, subscriptions, events; seeds = plan_types, feature_flags, regions; metrics = MRR, DAU, activation_rate, churn
- **Marketing**: entities = campaigns, leads, conversions; seeds = channel_types, utm_sources, regions; metrics = CAC, ROAS, pipeline_value

After generating the scaffold, briefly explain to the user what was created and ask for confirmation before proceeding to infrastructure.

---

## Phase 3 — Collect infrastructure parameters

### Mode detection

Check if a `dbt-project.yaml` file exists in the current directory.

- **If it exists** → read all infrastructure parameters from it automatically.
- **If it does not exist** → ask interactively in groups of 3–4 questions.

### Parameters to collect

#### dbt Cloud
| Variable | Description | Example |
|---|---|---|
| `dbt_account_id` | dbt Cloud account ID | `530` |
| `dbt_host_url` | API host URL | `https://emea.dbt.com/api` |
| `dbt_token` | Account Admin service token (**sensitive**) | `dbtc_...` |

#### Project
| Variable | Description | Example |
|---|---|---|
| `project_name` | Name of the dbt Cloud project | `my_project` |
| `git_remote_url` | SSH URL of the GitHub repo | `git@github.com:org/repo.git` |
| `github_installation_id` | GitHub App installation ID | `103071669` |
| `dbt_version` | dbt version | `versionless` |

##### Auto-discovering `github_installation_id`

Do not ask the user for this value. Discover it automatically by calling the dbt Cloud API once you have `dbt_account_id`, `dbt_host_url`, and `dbt_token`:

```bash
curl -s \
  -H "Authorization: Token $TF_VAR_dbt_token" \
  "{dbt_host_url}/v3/accounts/{dbt_account_id}/github/installations/" \
  | jq '.data[] | {id: .id, login: .account.login}'
```

Match the result whose `login` corresponds to the GitHub organisation or user that owns the repo. Use that `id` as `github_installation_id`.

If the endpoint returns an empty list or errors, fall back to asking the user.

#### Snowflake
| Variable | Description | Example |
|---|---|---|
| `snowflake_account` | Snowflake account identifier | `zna84829` |
| `snowflake_database` | Snowflake database | `Analytics` |
| `snowflake_warehouse` | Snowflake warehouse | `transforming` |
| `snowflake_user` | Snowflake user | `MY_USER` |
| `snowflake_password` | Snowflake password (**sensitive**) | — |
| `snowflake_role` | Snowflake role (optional) | `""` |

#### Schemas
| Variable | Description | Default |
|---|---|---|
| `schema_prefix` | Prefix for all schemas | `dbt_myproject` |
| `schema_development` | Development schema suffix | `dev` |
| `schema_staging` | Staging schema suffix | `staging` |
| `schema_production` | Production schema suffix | `prod` |

#### Jobs
| Variable | Description | Default |
|---|---|---|
| `daily_job_schedule_hours` | UTC hours for daily builds | `[6]` |

---

## Phase 4 — Create Terraform files

Create a `terraform/` directory with these files filled with the collected values:

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

**`terraform/variables.tf`** — declare all variables. Mark `dbt_token` and `snowflake_password` as `sensitive = true`.

**`terraform/terraform.tfvars`** — non-sensitive values only. Never write tokens or passwords here.

**`terraform/main.tf`**
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
  depends_on    = [dbtcloud_repository.this]
}

resource "dbtcloud_environment" "staging" {
  project_id      = dbtcloud_project.this.id
  name            = "Staging"
  dbt_version     = var.dbt_version
  type            = "deployment"
  deployment_type = "staging"
  credential_id   = dbtcloud_snowflake_credential.staging.credential_id
  connection_id   = dbtcloud_global_connection.snowflake.id
  depends_on      = [dbtcloud_repository.this]
}

resource "dbtcloud_environment" "production" {
  project_id      = dbtcloud_project.this.id
  name            = "Production"
  dbt_version     = var.dbt_version
  type            = "deployment"
  deployment_type = "production"
  credential_id   = dbtcloud_snowflake_credential.production.credential_id
  connection_id   = dbtcloud_global_connection.snowflake.id
  depends_on      = [dbtcloud_repository.this]
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

---

## Phase 5 — Update .gitignore

Ensure these entries exist in `.gitignore` at the project root:
```
.mcp.json
dbt-project.yaml
terraform/.terraform/
terraform/terraform.tfstate
terraform/terraform.tfstate.backup
terraform/.terraform.lock.hcl
```

---

## Phase 6 — Run Terraform

Set sensitive env vars:
```bash
export TF_VAR_dbt_token="<dbt_token>"
export TF_VAR_snowflake_password="<snowflake_password>"
```

Then run:
```bash
cd terraform
terraform init
terraform apply -auto-approve
```

Capture outputs after apply: `project_id`, `production_environment_id`, `staging_environment_id`.

---

## Phase 7 — Configure dbt Cloud MCP server

**Important:** MCP host URL does NOT include `/api`.
Format: `https://emea.dbt.com` (not `https://emea.dbt.com/api`).

Create `.mcp.json` at the project root with the token hardcoded (file is gitignored):

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

---

## Phase 8 — Done

Summarize what was created:
- 📁 dbt project scaffold (models, sources, Semantic Layer YAMLs)
- ⚙️ Terraform resources applied (project, environments, jobs, Semantic Layer)
- 🔌 `.mcp.json` configured with dbt Cloud MCP

Remind the user:
- ⚠️ `dbtcloud_semantic_layer_configuration` requires a successful job run in Production. Trigger "Daily Build (Production)" manually in dbt Cloud to complete the Semantic Layer setup.
- 🔁 Restart Claude Code (`claude --continue` or reopen) to load the new MCP server.

---

## Notes

- `dbtcloud_semantic_layer_configuration` fails if no successful run exists in the target environment — re-run `terraform apply` after triggering the job.
- `dbt_version` drift: provider may show benign updates from `versionless` to `latest` — safe to ignore.
- Provider v1.8+ required for Semantic Layer resources.
- `github_installation_id` for the `novarz` org is `103071669`.
- Sensitive files are gitignored: `.mcp.json`, `dbt-project.yaml`, `terraform/terraform.tfstate`.
