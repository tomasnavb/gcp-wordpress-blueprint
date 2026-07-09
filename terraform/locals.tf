locals {
  # Roles
  roles = {
    iap_tunnel_accessor     = "roles/iap.tunnelResourceAccessor"
    cloudsql_editor         = "roles/cloudsql.editor"
    bucket_admin            = "roles/storage.admin"
    secret_manager_accessor = "roles/secretmanager.secretAccessor"
    fn_invoker              = "roles/run.invoker"
    compute_viewer          = "roles/compute.viewer"
    log_writer              = "roles/logging.logWriter"
    os_admin_login          = "roles/compute.osAdminLogin"
    custom_db_backup_role = {
      id          = "dbBackupRole"
      title       = "Database Backup Role"
      description = "Custom role for Cloud Function to backup CloudSQL database to Cloud Storage"
      permissions = [
        "cloudsql.instances.get",
        "cloudsql.instances.list",
        "cloudsql.instances.export",
        "cloudsql.backupRuns.create",
        "cloudsql.backupRuns.export",
        "cloudsql.backupRuns.list",
        "cloudsql.backupRuns.get"
      ]
    }
  }

  # Service accounts
  service_accounts = {
    mgmt         = "serviceAccount:${google_service_account.mgmt_vm.email}"
    prod         = "serviceAccount:${google_service_account.prod_vm.email}"
    sql_instance = "serviceAccount:${google_sql_database_instance.main.service_account_email_address}"
    fn           = "serviceAccount:${google_service_account.cloudsql_backup_fn.email}"
    scheduler    = "serviceAccount:${google_service_account.scheduler_fn_invoker.email}"
  }

  # Virtual machines
  source_image = "projects/${var.project_id}/global/images/family/wordpress-golden"
  disk_size_gb = 10
  disk_type    = "pd-standard"

  # Cloud Storage
  db_backup_bucket_name = "${var.db_backup_bucket_base_name}-${var.project_id}"
  scripts_bucket_name   = "${var.scripts_bucket_base_name}-${var.project_id}"

  # Cloud Scheduler
  scheduler_export_name          = "export-db-backup"
  scheduler_export_description   = "Cloud Scheduler job to trigger Cloud Function for CloudSQL export backup"
  scheduler_export_schedule      = "0 0 * * *" # Daily at midnight
  scheduler_snapshot_name        = "snapshot-db-backup"
  scheduler_snapshot_description = "Cloud Scheduler job to trigger Cloud Function for CloudSQL snapshot backup"
  scheduler_snapshot_schedule    = "0 */4 * * *" # Every 4 hours
  scheduler_fn_backup_type       = { standard = "export", fast = "snapshot" }

  secrets = {
    "wordpress-db-name"                = var.db_name
    "wordpress-db-user"                = var.db_user
    "wordpress-db-password"            = random_password.db_password.result
    "wordpress-db-host"                = google_sql_database_instance.main.private_ip_address
    "wordpress-db-instance-connection" = google_sql_database_instance.main.connection_name
  }

}
