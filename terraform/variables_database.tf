variable "instance_name" {
  description = "Name for the Cloud SQL production instance"
  type        = string
}

variable "instance_region" {
  description = "GCP region for the Cloud SQL instance"
  type        = string
}

variable "instance_tier" {
  description = "Machine type for the Cloud SQL instance (e.g. db-custom-2-4096 for 2 vCPU / 4 GB RAM)"
  type        = string
}

variable "instance_edition" {
  description = "Cloud SQL edition (ENTERPRISE or ENTERPRISE_PLUS)"
  type        = string
  default     = "ENTERPRISE"
}

variable "instance_availability_type" {
  description = "Availability type for the Cloud SQL instance (REGIONAL for HA, ZONAL for single-zone)"
  type        = string
  default     = "REGIONAL"
}

variable "instance_disk_type" {
  description = "Disk type for the Cloud SQL instance (PD_SSD or PD_HDD)"
  type        = string
  default     = "PD_SSD"
}

variable "instance_disk_size_gb" {
  description = "Initial disk size in GB (disk_autoresize will grow it automatically)"
  type        = number
}

variable "db_name" {
  description = "Name of the MySQL database created for WordPress"
  type        = string
  default     = "wordpress"
}

variable "db_charset" {
  description = "Character set for the WordPress database"
  type        = string
  default     = "utf8mb4"
}

variable "db_collation" {
  description = "Collation for the WordPress database"
  type        = string
  default     = "utf8mb4_unicode_ci"
}

variable "db_user" {
  description = "Username for the WordPress application database user"
  type        = string
  default     = "wordpress"
}
