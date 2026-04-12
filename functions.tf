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

resource "google_cloud_scheduler_job" "trigger_backup" {
  name             = "trigger-db-backup"
  description      = "Cloud Scheduler job to trigger Cloud Function for CloudSQL backup every 24 hours"
  schedule         = "0 0 * * *" # Every 24 hours at midnight
  time_zone        = "UTC+1" # Western Europe time zone
  attempt_deadline = "60s"

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions_function.cloudsql_backup.https_trigger_url
    headers = {
      "Content-Type" = "application/json"
    }
    body = base64decode(jsonencode({type = "export"}))
    oidc_token {
      service_account_email = google_service_account.cloudsql_backup_fn.email
    }
  }
  
}
