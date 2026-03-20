# dbt Cloud Terraform Template

Terraform template to provision a complete dbt Cloud project from scratch, including Snowflake connection, environments (Dev / Staging / Production), scheduled jobs, Slim CI, and Semantic Layer.

## ✨ New: One-command setup

This template ships with a **Claude Code slash command** (`/dbt-project-setup`) that automates the entire setup — no manual Terraform editing needed.

### How to use

1. **Clone this repo** into your project (or use it as a GitHub template)
2. **Open the project** in Claude Code
3. Run the command:

```
/dbt-project-setup
```

That's it. Claude will:
- Ask for your project parameters (or read them from `dbt-project.yaml`)
- Generate all Terraform files
- Run `terraform apply` automatically
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
| **Daily Build** | Runs `dbt deps + dbt build + dbt docs generate` on Staging and Production |
| **Slim CI** | Triggered on PRs, runs modified models only with compare changes |
| **Semantic Layer** | Configured on Production with Snowflake credentials + service token |
| **dbt MCP** | dbt Cloud MCP server configured in `.mcp.json` |

---

## Manual usage (raw Terraform)

If you prefer to manage Terraform yourself:

### 1. Fill in `terraform/terraform.tfvars`

```hcl
dbt_account_id = 530
dbt_host_url   = "https://emea.dbt.com/api"
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

- **`dbtcloud_semantic_layer_configuration`** requires a successful job run in the target environment. If it fails on first apply, trigger "Daily Build (Production)" manually and re-run `terraform apply`.
- **`dbt_version` drift**: provider returns `"latest"` but config uses `"versionless"` — causes benign updates on every apply, safe to ignore.
- **Provider v1.8+** required for Semantic Layer resources.
- **`github_installation_id`** is fixed per GitHub org. For the `novarz` org it is `103071669`.
- **Host URL**: use `https://{prefix}.dbt.com/api` for Terraform but `https://{prefix}.dbt.com` (without `/api`) for the MCP server.

---

## Sensitive files (gitignored)

| File | Contains |
|---|---|
| `.mcp.json` | dbt token for MCP server |
| `terraform/terraform.tfstate` | Terraform state |
| `dbt-project.yaml` | Your project config (if used) |
