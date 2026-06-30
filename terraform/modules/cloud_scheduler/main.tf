# Cloud Scheduler Job to trigger Cloud Function for CloudSQL backup

resource "google_cloud_scheduler_job" "trigger_backup" {
  name             = var.name
  description      = var.description
  schedule         = var.schedule
  time_zone        = var.time_zone
  attempt_deadline = var.attempt_deadline

  http_target {
    http_method = var.http_method
    uri         = var.backup_fn_uri
    headers = {
      "Content-Type" = "application/json"
    }
    body = base64encode(jsonencode({ type = var.fn_backup_type }))
    oidc_token {
      service_account_email = var.invoker_service_account_email
    }
  }

  retry_config {
    retry_count          = var.retry_count
    max_retry_duration   = var.max_retry_duration
    min_backoff_duration = var.min_backoff_duration
    max_backoff_duration = var.max_backoff_duration
    max_doublings        = var.max_doublings
  }

}
