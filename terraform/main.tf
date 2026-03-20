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
  name = "Snowflake"

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

# ─── Job: Daily Build ─────────────────────────────────────────────────────────

resource "dbtcloud_job" "daily" {
  project_id     = dbtcloud_project.this.id
  environment_id = dbtcloud_environment.staging.environment_id
  name           = "Daily Build"
  execute_steps  = ["dbt build"]
  dbt_version    = var.dbt_version

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
  execute_steps  = ["dbt build --select state:modified+ --defer --state ./artifacts"]
  dbt_version    = var.dbt_version

  # Defer to the staging environment state so Slim CI only runs modified nodes
  deferring_environment_id = dbtcloud_environment.staging.environment_id

  # Show what changed vs the deferred state
  run_compare_changes = true

  triggers = {
    github_webhook       = true
    git_provider_webhook = true
    schedule             = false
    on_merge             = false
  }
}
