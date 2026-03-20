# dbt Cloud Terraform Template

Terraform template to provision a complete dbt Cloud project from scratch, including Snowflake connection, environments (Dev / Staging / Production), scheduled jobs, Slim CI, and Semantic Layer.

---

## Prerequisites

Before running `/dbt-project-setup`, make sure you have the following:

### Tools
| Tool | Why | Install |
|---|---|---|
| **Claude Code** | Runs the `/dbt-project-setup` slash command | [claude.ai/code](https://claude.ai/code) |
| **Terraform** ≥ 1.5 | Provisions dbt Cloud resources | `brew install terraform` |
| **`uvx`** (via `uv`) | Runs the dbt Cloud MCP server | `brew install uv` |
| **`jq`** | Parses API responses during setup | `brew install jq` |
| **`curl`** | Queries dbt Cloud API (auto-discover GitHub installation ID) | Pre-installed on macOS/Linux |
| **GitHub CLI (`gh`)** | Optional — useful for repo management | `brew install gh` |

### Accounts & access
| Requirement | Details |
|---|---|
| **dbt Cloud account** | Must have Account Admin permissions |
| **dbt Cloud service token** | Type: Account Admin. Found in Account Settings → Service Tokens |
| **Snowflake account** | User must have CREATE SCHEMA on the target database |
| **GitHub repository** | SSH URL format: `git@github.com:org/repo.git` |
| **GitHub App installed** | The dbt Cloud GitHub App must be installed on your GitHub org. Install at: Account Settings → Integrations → GitHub |

### Region & URL reference

> ⚠️ **Terraform and the MCP server use different URL formats.**
>
> - **Terraform** (`dbt_host_url`): account-prefixed URL **with** `/api`
> - **MCP** (`DBT_HOST`): account-prefixed URL **without** `/api`
>
> Your account prefix is shown in dbt Cloud → Account Settings (e.g. `pk455`).
> Full reference: [dbt Cloud regions & IP addresses](https://docs.getdbt.com/docs/cloud/about-cloud/access-regions-ip-addresses)

#### Region codes — format: `https://ACCOUNT_PREFIX.{region}.dbt.com`

| Cloud | Location | Region code | Terraform `dbt_host_url` | MCP `DBT_HOST` |
|---|---|---|---|---|
| AWS | North America (Virginia) | `us1` | `https://pk455.us1.dbt.com/api` | `https://pk455.us1.dbt.com` |
| AWS | EMEA (Frankfurt) | `eu1` | `https://pk455.eu1.dbt.com/api` | `https://pk455.eu1.dbt.com` |
| AWS | APAC (Sydney) | `au1` | `https://pk455.au1.dbt.com/api` | `https://pk455.au1.dbt.com` |
| AWS | Japan (Tokyo) | `jp1` | `https://pk455.jp1.dbt.com/api` | `https://pk455.jp1.dbt.com` |
| GCP | North America | `us3` | `https://pk455.us3.dbt.com/api` | `https://pk455.us3.dbt.com` |
| GCP | EMEA (London) | `eu3` | `https://pk455.eu3.dbt.com/api` | `https://pk455.eu3.dbt.com` |
| GCP | EMEA (Frankfurt) | `eu4` | `https://pk455.eu4.dbt.com/api` | `https://pk455.eu4.dbt.com` |
| Azure | North America (Virginia) | `us2` | `https://pk455.us2.dbt.com/api` | `https://pk455.us2.dbt.com` |
| Azure | EMEA (Ireland) | `eu2` | `https://pk455.eu2.dbt.com/api` | `https://pk455.eu2.dbt.com` |

---

## ✨ One-command setup

This template ships with a **Claude Code slash command** (`/dbt-project-setup`) that automates the entire setup — no manual Terraform editing needed.

### How to use

1. **Clone this repo** into your project (or use it as a GitHub template)
2. **Open the project** in Claude Code
3. Run the command:

```
/dbt-project-setup
```

That's it. Claude will:
- Ask about your business domain, data sources, and key metrics
- Scaffold the dbt project structure (models, seeds, tests, Semantic Layer YAML)
- Ask for your infrastructure parameters (or read them from `dbt-project.yaml`)
- Auto-discover `github_installation_id` via the dbt Cloud API
- Generate all Terraform files and run `terraform apply`
- Configure the **dbt Cloud MCP server** in `.mcp.json`

### Config file mode (fully automated)

Copy and fill in `dbt-project.example.yaml`:

```bash
cp dbt-project.example.yaml dbt-project.yaml
# edit dbt-project.yaml with your values
```

Set sensitive credentials as environment variables:

```bash
export TF_VAR_dbt_token="dbtc_..."
export TF_VAR_snowflake_password="..."
```

Then just run `/dbt-project-setup` — no questions asked.

---

## What gets provisioned

| Resource | Details |
|---|---|
| **Project** | dbt Cloud project linked to your GitHub repo |
| **Connection** | Snowflake global connection ("Snowflake Terraform") |
| **Environments** | Development, Staging (staging), Production (production) |
| **Daily Build (Staging)** | `dbt deps + dbt build + dbt docs generate` — scheduled |
| **Daily Build (Production)** | `dbt deps + dbt build + dbt docs generate` — scheduled |
| **Slim CI** | Triggered on PRs, runs modified models only with compare changes |
| **Semantic Layer** | Configured on Production with Snowflake credentials + service token |
| **dbt MCP** | dbt Cloud MCP server configured in `.mcp.json` |

---

## Manual usage (raw Terraform)

If you prefer to manage Terraform yourself:

### 1. Fill in `terraform/terraform.tfvars`

```hcl
dbt_account_id = 530
dbt_host_url   = "https://emea.dbt.com/api"   # EMEA example
project_name   = "my_project"
# ... etc
```

### 2. Set sensitive variables as env vars

```bash
export TF_VAR_dbt_token="dbtc_..."
export TF_VAR_snowflake_password="..."
```

### 3. Apply

```bash
cd terraform
terraform init
terraform apply
```

### 4. Get the Semantic Layer token

```bash
terraform output -raw semantic_layer_token
```

---

## Known gotchas

- **`dbtcloud_semantic_layer_configuration`** requires a successful job run in the target environment. If it fails on first apply, trigger "Daily Build (Production)" manually in dbt Cloud and re-run `terraform apply`.
- **`dbt_version` drift**: provider returns `"latest"` but config uses `"versionless"` — causes benign updates on every apply, safe to ignore.
- **Provider v1.8+** required for Semantic Layer resources. Do not use `~> 0.3`.
- **`github_installation_id`** is fixed per GitHub org — not per project. The `/dbt-project-setup` command discovers it automatically via API.
- **Host URL format**: Terraform needs `/api` suffix (`https://emea.dbt.com/api`), the MCP server does **not** (`https://emea.dbt.com`). Mixing these up is the most common setup error.
- **SSH remote URL required**: Terraform expects `git@github.com:org/repo.git`, not the HTTPS URL.
- **`dbtcloud_project_repository`** must be a separate resource from `dbtcloud_repository` — do not inline the repository link inside the project resource.

---

## Sensitive files (gitignored)

| File | Contains |
|---|---|
| `.mcp.json` | dbt token for MCP server |
| `dbt-project.yaml` | Your project config with credentials |
| `terraform/terraform.tfstate` | Terraform state |
| `terraform/terraform.tfstate.backup` | Terraform state backup |
| `terraform/.terraform/` | Provider cache |
