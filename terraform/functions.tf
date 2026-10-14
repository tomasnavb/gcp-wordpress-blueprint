# Cloud Function to backup CloudSQL database to Cloud Storage
resource "google_cloudfunctions2_function" "db_backup_fn" {
  # The build SA bindings must exist and have propagated before the first build starts (see IAM.tf, 3.6)
  depends_on = [
    google_project_service.gcp_services,
    time_sleep.fn_build_iam_propagation,
  ]
  name        = var.function_name
  location    = var.function_region
  description = var.function_description

  build_config {
    runtime         = "python311"
    entry_point     = "run_backup"
    service_account = google_service_account.cloudsql_backup_fn_build.id
    source {
      storage_source {
        bucket = google_storage_bucket.scripts.name
        object = google_storage_bucket_object.function_code.name

      }
    }

  }
  service_config {
    timeout_seconds       = var.function_timeout_sec
    service_account_email = google_service_account.cloudsql_backup_fn.email
    environment_variables = {
      GCP_PROJECT_ID          = var.project_id
      CLOUD_SQL_INSTANCE_NAME = var.instance_name
      BACKUP_BUCKET_NAME      = local.db_backup_bucket_name
    }
  }

}

/* Cloud Scheduler jobs that trigger the Cloud Function for CloudSQL backups:
- Export: daily, to the backup bucket, where a lifecycle rule deletes it after 90 days.
- Snapshot: an on-demand Cloud SQL backup every 4 hours. Cloud SQL does not delete on-demand backups
  and nothing here does either yet, so they accumulate (docs/to-do.md, T13).
Schedules are evaluated in var.time_zone (Europe/Paris in terraform.tfvars). */

module "export_db_scheduler" {
  depends_on = [google_project_service.gcp_services]
  source     = "./modules/cloud_scheduler"


  name                          = local.scheduler_export_name
  description                   = local.scheduler_export_description
  schedule                      = local.scheduler_export_schedule # Daily at midnight
  backup_fn_uri                 = google_cloudfunctions2_function.db_backup_fn.url
  fn_backup_type                = local.scheduler_fn_backup_type.standard # Standard for export backup for 90 days retention
  invoker_service_account_email = google_service_account.scheduler_fn_invoker.email
  http_method                   = var.http_method
  min_backoff_duration          = var.min_backoff_duration
  time_zone                     = var.time_zone
  max_doublings                 = var.max_doublings
  retry_count                   = var.retry_count
  max_backoff_duration          = var.max_backoff_duration
  attempt_deadline              = var.attempt_deadline
  max_retry_duration            = var.max_retry_duration
}

module "snapshot_db_scheduler" {
  depends_on = [google_project_service.gcp_services]
  source     = "./modules/cloud_scheduler"

  name                          = local.scheduler_snapshot_name
  description                   = local.scheduler_snapshot_description
  schedule                      = local.scheduler_snapshot_schedule # Every 4 hours
  backup_fn_uri                 = google_cloudfunctions2_function.db_backup_fn.url
  fn_backup_type                = local.scheduler_fn_backup_type.fast # Fast: on-demand snapshot backup, no retention yet
  invoker_service_account_email = google_service_account.scheduler_fn_invoker.email
  http_method                   = var.http_method
  min_backoff_duration          = var.min_backoff_duration
  time_zone                     = var.time_zone
  max_doublings                 = var.max_doublings
  retry_count                   = var.retry_count
  max_backoff_duration          = var.max_backoff_duration
  attempt_deadline              = var.attempt_deadline
  max_retry_duration            = var.max_retry_duration

}
