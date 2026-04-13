variable "scheduler_name" {
  description = "Name of the Cloud Scheduler job to trigger Cloud Function for CloudSQL backup"
  type        = string
  default     = "trigger-db-backup"
}

variable "scheduler_description"    {
  description = "Description of the Cloud Scheduler job to trigger Cloud Function for CloudSQL backup"
  type        = string
  default     = "Cloud Scheduler job to trigger Cloud Function for CloudSQL"
  
}

variable "scheduler_schedule" {
  description = "Schedule for the Cloud Scheduler job to trigger Cloud Function for CloudSQL backup"
  type        = string
}

variable "scheduler_time_zone" {
  description = "Time zone for the Cloud Scheduler job to trigger Cloud Function for CloudSQL backup. Default is set to UTC+1 (Western Europe time zone)"
  type        = string
  default     = "UTC+1"
}

variable "fn_uri" {
    description = "URI for the backup Cloud Function"
    type        = string
}

variable "backup_type" {
  description = "Type of backup to trigger"
  type        = string
}

variable "invoker_service_account_email" {
    description = "Service account for the specific functions's invoker"
    type        = string
}