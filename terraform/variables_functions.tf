# Cloud Function
variable "function_name" {
  description = "Name for the Cloud Function that runs CloudSQL backups"
  type        = string
}

variable "function_description" {
  description = "Human-readable description for the Cloud Function"
  type        = string
  default     = "Manages CloudSQL export and snapshot backups to Cloud Storage"
}

variable "function_region" {
  description = "GCP region where the Cloud Function is deployed"
  type        = string
}

variable "function_timeout_sec" {
  description = "Maximum execution time for the Cloud Function in seconds (exports can take several minutes)"
  type        = number
  default     = 600
}

# Cloud Scheduler (shared by both export and snapshot jobs)
variable "time_zone" {
  description = "Time zone for the Cloud Scheduler cron expressions (e.g. Europe/Paris)"
  type        = string
}

variable "http_method" {
  description = "HTTP method used by Cloud Scheduler when invoking the Cloud Function"
  type        = string
}

variable "attempt_deadline" {
  description = "Time limit for a single HTTP attempt by the scheduler before it is considered failed (e.g. 60s)"
  type        = string
}

variable "retry_count" {
  description = "Maximum number of retry attempts if the Cloud Function returns an error"
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
