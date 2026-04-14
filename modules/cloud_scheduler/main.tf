# Cloud Scheduler Job to trigger Cloud Function for CloudSQL backup

resource "google_cloud_scheduler_job" "trigger_backup" {
  name             = var.scheduler_name
  description      = var.scheduler_description
  schedule         = var.scheduler_schedule
  time_zone        = var.scheduler_time_zone
  attempt_deadline = "60s"

  http_target {
    http_method = "POST"
    uri         = var.fn_uri
    headers = {
      "Content-Type" = "application/json"
    }
    body = base64encode(jsonencode({ type = var.backup_type }))
    oidc_token {
      service_account_email = var.invoker_service_account_email
    }
  }

}