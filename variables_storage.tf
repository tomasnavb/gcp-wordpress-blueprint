variable "db_backup_bucket_base_name" {
  description = "value"
  type        = string
  default     = "wordpress-bucket-prod"
}

variable "scripts_bucket_base_name" {
  description = "Base name for the scripts bucket"
  type        = string
  default     = "wordpress-scripts-bucket"

}