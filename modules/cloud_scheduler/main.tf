# Cloud Scheduler Job to trigger Cloud Function for CloudSQL backup

resource "google_cloud_scheduler_job" "trigger_backup" {
  name             = var.name
  description      = var.description
  schedule         = var.schedule
  time_zone        = var.time_zone
  attempt_deadline = local.attempt_deadline

  http_target {
    http_method = local.http_method
    uri         = var.backup_fn_uri
    headers = {
      "Content-Type" = local.content_type
    }
    body = base64encode(jsonencode({ type = var.fn_backup_type }))
    oidc_token {
      service_account_email = var.invoker_service_account_email
    }
  }

  retry_config {
    retry_count          = local.retry_count
    max_retry_duration   = local.max_retry_duration
    min_backoff_duration = local.min_backoff_duration
    max_backoff_duration = local.max_backoff_duration
    max_doublings        = local.max_doublings
  }

}
