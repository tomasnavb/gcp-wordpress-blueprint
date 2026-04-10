# Cloud Function to backup CloudSQL database to Cloud Storage
resource "google_cloudfunctions_function" "cloudsql_backup" {
  name                  = var.db_backup_fn_name
  description           = "Cloud Function to backup CloudSQL database to Cloud Storage"
  runtime               = "python311"
  trigger_http          = true
  timeout               = 60
  source_archive_bucket = google_storage_bucket.scripts
  source_archive_object = google_storage_bucket_object.function_code.name
  entry_point           = "run_backup"

  environment_variables = {
    GCP_PROJECT_ID          = var.project_id
    CLOUD_SQL_INSTANCE_NAME = var.db_instance_name
    BACKUP_BUCKET_NAME      = local.full_bucket_name
  }

  service_account_email = google_service_account.cloudsql_backup_fn.email
}
