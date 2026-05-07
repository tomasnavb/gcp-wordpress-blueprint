variable "instance_name" {
  description = "Name for the CloudSQL production database"
  type        = string
}

variable "instance_region" {
  description = "Region for the CloudSQL production database"
  type        = string
  default     = "europe-west9"
}

variable "instance_version" {
  description = "CloudSQL database engine MySQL"
  type        = string
  default     = "MYSQL_8_4"
}

variable "enable_instance_deletion_protection" {
  description = "Deletion protection for CloudSQL instance to prevent accidental deletion"
  type        = bool
  default     = true
}

variable "enable_instance_disk_autoresize" {
  description = "Enable disk autoresize for CloudSQL instance to allow automatic resizing when disk space is low"
  type        = bool
  default     = false
}

variable "instance_tier" {
  description = "Machine type for CloudSQL instance (db-custom-4-16384, 4 vCPU, 16 GB RAM for moderate traffic)"
  type        = string
  default     = "db-custom-4-16384"
}

variable "instance_edition" {
  description = "Edition for the CloudSQL instance (ENTERPRISE sufficient for general machine usage)"
  type        = string
  default     = "ENTERPRISE"
}

variable "instance_availability_type" {
  description = "Availability type for CloudSQL instance (REGIONAL for high-availability)"
  type        = string
  default     = "REGIONAL"
}

variable "instance_disk_type" {
  description = "value"
  type        = string
  default     = "PD_SSD"
}

variable "instance_disk_size_gb" {
  description = "Initial disk size for CloudSQL instance (100 GB recommended for moderate traffic)"
  type        = number
  default     = 100

}

variable "db_name" {
  description = "Name for the Wordpress database to be created within the CloudSQL instance"
  type        = string
  default     = "wordpress"
}

variable "db_charset" {
  description = "Character set for the Wordpress database"
  type        = string
  default     = "utf8mb4"
}

variable "db_collation" {
  description = "Collation for the Wordpress database"
  type        = string
  default     = "utf8mb4_unicode_ci"
}

variable "db_user" {
  description = "Username for the Wordpress database user"
  type        = string
  default     = "wordpress"
}