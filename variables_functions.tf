variable "function_name" {
  description = "Name for the CloudSQL backup function"
  type        = string
  default     = "wordpress-fn-db-backup-prod"
}

variable "function_description" {
  description = "Description for the CloudSQL backup function"
  type        = string
  default     = "This function manages the DB backup snapshots and exports"
}

variable "function_region" {
  description = "Region for the CloudSQL backup function"
  type        = string
  default     = "europe-west9"
}

variable "function_timeout_sec" {
  description = "Timeout for the CloudSQL backup function in seconds"
  type        = number
  default     = 600
}