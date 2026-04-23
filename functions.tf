# Cloud Function to backup CloudSQL database to Cloud Storage
resource "google_cloudfunctions2_function" "db_backup_fn" {
  depends_on  = [google_project_service.gcp_services]
  name        = var.function_name
  location    = var.function_region
  description = "This functions manages the DB backup snapshots and exports"

  build_config {
    runtime     = local.function_runtime
    entry_point = local.function_entry_point
    source {
      storage_source {
        bucket = google_storage_bucket.scripts.self_link
        object = google_storage_bucket_object.function_code.self_link

      }
    }

  }
  service_config {
    timeout_seconds       = var.function_timeout_sec
    service_account_email = google_service_account.cloudsql_backup_fn.email
    environment_variables = {
      GCP_PROJECT_ID          = var.project_id
      CLOUD_SQL_INSTANCE_NAME = var.sql_instance_name
      BACKUP_BUCKET_NAME      = local.scripts_bucket_name
    }
  }

}

/* Cloud Scheduler jobs to trigger Cloud Function for CloudSQL backups - Export backup for 90 days retention and Snapshot backup
every 4 hours for 7 days retention for point-in-time recovery. Using default time-zone setted on UTC+1 (Western Europe time zone)*/

module "export_db_scheduler" {
  depends_on = [google_project_service.gcp_services]
  source     = "./modules/cloud_scheduler"

  name                          = "export-db-backup"
  description                   = "Cloud Scheduler job to trigger Cloud Function for CloudSQL export backup"
  schedule                      = "0 0 * * *" # Daily at midnight
  backup_fn_uri                 = google_cloudfunctions2_function.db_backup_fn.https_trigger_url
  fn_backup_type                = "export"
  invoker_service_account_email = google_service_account.scheduler_fn_invoker.email
}

module "snapshot_db_scheduler" {
  depends_on = [google_project_service.gcp_services]
  source     = "./modules/cloud_scheduler"

  name                          = "snapshot-db-backup"
  description                   = "Cloud Scheduler job to trigger Cloud Function for CloudSQL snapshot backup"
  schedule                      = "0 */4 * * *" # Every 4 hours
  backup_fn_uri                 = google_cloudfunctions2_function.db_backup_fn.https_trigger_url
  fn_backup_type                = "snapshot"
  invoker_service_account_email = google_service_account.scheduler_fn_invoker.email

}
