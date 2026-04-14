# Cloud Function to backup CloudSQL database to Cloud Storage
resource "google_cloudfunctions2_function" "db_backup_function" {
  name        = var.db_backup_fn_name
  location    = var.db_backup_fn_region
  description = "This functions manages the DB backup snapshots and exports"

  build_config {
    runtime     = "python311"
    entry_point = "run_backup"
    source {
      storage_source {
        bucket = google_storage_bucket.scripts.self_link
        object = google_storage_bucket_object.function_code.self_link

      }
    }

  }
  service_config {
    timeout_seconds       = 600
    service_account_email = google_service_account.cloudsql_backup_fn.email
    environment_variables = {
      GCP_PROJECT_ID          = var.project_id
      CLOUD_SQL_INSTANCE_NAME = var.db_instance_name
      BACKUP_BUCKET_NAME      = local.scripts_bucket_name
    }
  }

}

/* Cloud Scheduler jobs to trigger Cloud Function for CloudSQL backups - Export backup for 90 days retention and Snapshot backup
every 4 hours for 7 days retention for point-in-time recovery. Using default time-zone setted on UTC+1 (Western Europe time zone)*/

module "export_db_scheduler" {
  source = "./modules/cloud_scheduler"

  scheduler_name                = "export-db-backup"
  scheduler_description         = "Cloud Scheduler job to trigger Cloud Function for CloudSQL export backup"
  scheduler_schedule            = "0 0 * * *" # Daily at midnight
  fn_uri                        = google_cloudfunctions2_function.db_backup_function.https_trigger_url
  backup_type                   = "export"
  invoker_service_account_email = google_service_account.scheduler_fn_invoker.email
}

module "snapshot_db_scheduler" {
  source = "./modules/cloud_scheduler"

  scheduler_name                = "snapshot-db-backup"
  scheduler_description         = "Cloud Scheduler job to trigger Cloud Function for CloudSQL snapshot backup"
  scheduler_schedule            = "0 */4 * * *" # Every 4 hours
  fn_uri                        = google_cloudfunctions2_function.db_backup_function.https_trigger_url
  backup_type                   = "snapshot"
  invoker_service_account_email = google_service_account.scheduler_fn_invoker.email

}
