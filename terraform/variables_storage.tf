variable "db_backup_bucket_base_name" {
  description = "Base name for the CloudSQL backup bucket (project_id is appended as suffix to ensure uniqueness)"
  type        = string
}

variable "scripts_bucket_base_name" {
  description = "Base name for the Cloud Function source code bucket (project_id is appended as suffix to ensure uniqueness)"
  type        = string
}
