variable "name" {
  description = "Name of the Cloud Scheduler job to trigger Cloud Function for CloudSQL backup"
  type        = string
  default     = "trigger-db-backup"
}

variable "description" {
  description = "Description of the Cloud Scheduler job to trigger Cloud Function for CloudSQL backup"
  type        = string
  default     = "Cloud Scheduler job to trigger Cloud Function for CloudSQL"

}

variable "schedule" {
  description = "Schedule for the Cloud Scheduler job to trigger Cloud Function for CloudSQL backup. Default is set to daily at midnight (0 0 * * *)"
  type        = string
  default     = "0 0 * * *"
}

variable "time_zone" {
  description = "Time zone for the Cloud Scheduler job to trigger Cloud Function for CloudSQL backup. Default is set to UTC+1 (Western Europe time zone)"
  type        = string
  default     = "UTC+1"
}

variable "backup_fn_uri" {
  description = "URI of the Cloud Function to trigger for CloudSQL backup"
  type        = string
}

variable "fn_backup_type" {
  description = "The type of backup to perform, either 'export' for export backup or 'snapshot' for snapshot backup"
  type        = string
}

variable "invoker_service_account_email" {
  description = "Service account for the specific functions's invoker"
  type        = string
}

# Locals 

locals {
  attempt_deadline     = "60s"
  http_method          = "POST"
  content_type         = "application/json"
  retry_count          = 3
  max_retry_duration   = "300s"
  min_backoff_duration = "10s"
  max_backoff_duration = "60s"
  max_doublings        = 2
}