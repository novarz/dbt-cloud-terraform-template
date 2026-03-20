# ─── dbt Cloud ───────────────────────────────────────────────────────────────

variable "dbt_account_id" {
  description = "dbt Cloud Account ID"
  type        = number
}

variable "dbt_host_url" {
  description = "dbt Cloud host URL (e.g. https://emea.dbt.com)"
  type        = string
}

variable "dbt_token" {
  description = "dbt Cloud Service Token with Account Admin permissions"
  type        = string
  sensitive   = true
}

# ─── Project ──────────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Name of the dbt Cloud project"
  type        = string
}

variable "dbt_version" {
  description = "dbt version for environments (use 'versionless' for latest)"
  type        = string
  default     = "versionless"
}

# ─── Git repository ───────────────────────────────────────────────────────────

variable "git_remote_url" {
  description = "SSH URL of the git repository (e.g. git@github.com:org/repo.git)"
  type        = string
}

variable "git_clone_strategy" {
  description = "Clone strategy: github_app | deploy_key | azure_active_directory_app"
  type        = string
  default     = "github_app"
}

variable "github_installation_id" {
  description = "GitHub App installation ID (required if git_clone_strategy = github_app)"
  type        = number
  default     = null
}

# ─── Snowflake connection ─────────────────────────────────────────────────────

variable "snowflake_account" {
  description = "Snowflake account identifier (e.g. zna84829.eu-west-1)"
  type        = string
}

variable "snowflake_database" {
  description = "Snowflake database"
  type        = string
}

variable "snowflake_warehouse" {
  description = "Snowflake virtual warehouse"
  type        = string
}

variable "snowflake_user" {
  description = "Snowflake user"
  type        = string
}

variable "snowflake_password" {
  description = "Snowflake password"
  type        = string
  sensitive   = true
}

variable "snowflake_role" {
  description = "Snowflake role (leave empty to use default)"
  type        = string
  default     = ""
}

# ─── Environments / schemas ───────────────────────────────────────────────────

variable "schema_prefix" {
  description = "Prefix for all Snowflake schemas (e.g. dbt_sduran_terraform_test)"
  type        = string
}

variable "schema_development" {
  description = "Snowflake schema for the Development environment (prefix will be prepended)"
  type        = string
  default     = "dev"
}

variable "schema_staging" {
  description = "Snowflake schema for the Staging environment (prefix will be prepended)"
  type        = string
  default     = "staging"
}

# ─── Jobs ─────────────────────────────────────────────────────────────────────

variable "daily_job_schedule_hours" {
  description = "UTC hours at which the daily job runs (list)"
  type        = list(number)
  default     = [6]
}
