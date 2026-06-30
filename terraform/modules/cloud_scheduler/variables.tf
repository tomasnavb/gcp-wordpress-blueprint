variable "name" {
  description = "Name of the Cloud Scheduler job"
  type        = string
}

variable "description" {
  description = "Human-readable description for the Cloud Scheduler job"
  type        = string
}

variable "schedule" {
  description = "Cron expression defining when the job fires (e.g. '0 0 * * *' for daily at midnight)"
  type        = string
}

variable "time_zone" {
  description = "Time zone used to interpret the cron schedule expression (e.g. Europe/Paris)"
  type        = string
}

variable "backup_fn_uri" {
  description = "HTTPS trigger URL of the Cloud Function to invoke"
  type        = string
}

variable "fn_backup_type" {
  description = "Backup type sent in the request body to the function: 'export' (90-day retention) or 'snapshot' (7-day retention)"
  type        = string
}

variable "invoker_service_account_email" {
  description = "Email of the service account used in the OIDC token to authenticate the HTTP call to the Cloud Function"
  type        = string
}

variable "attempt_deadline" {
  description = "Time limit for a single HTTP attempt before it is considered failed (e.g. 60s)"
  type        = string
}

variable "http_method" {
  description = "HTTP method used when invoking the Cloud Function (POST)"
  type        = string
}

variable "retry_count" {
  description = "Maximum number of retry attempts if the function returns an error"
  type        = number
}

variable "max_retry_duration" {
  description = "Total time the scheduler will keep retrying a failed job (e.g. 300s)"
  type        = string
}

variable "min_backoff_duration" {
  description = "Minimum wait time between retry attempts (e.g. 10s)"
  type        = string
}

variable "max_backoff_duration" {
  description = "Maximum wait time between retry attempts (e.g. 60s)"
  type        = string
}

variable "max_doublings" {
  description = "Maximum number of times the backoff interval is doubled before hitting max_backoff_duration"
  type        = number
}
