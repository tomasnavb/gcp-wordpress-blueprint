/* Variables for Terraform configuration of a WordPress site on Google Cloud, including project settings, 
compute instance configurations, CloudSQL database settings, VPC and subnet configurations, and Cloud Function 
settings for database backups. */

# Variables for Google Cloud project configuration including project ID and region/zone.
variable "project_id" {
  description = "ID for the Google Cloud project"
  type        = string
}

variable "project_region" {
  description = "Google Cloud project region"
  type        = string
  default     = "us-central1"
}

variable "project_zone" {
  description = "Google Cloud project zone"
  type        = string
  default     = "us-central1-a"
}


# Compute instance configurations for production and management VMs, including machine types and boot disk images.
variable "vm_prod_name" {
  description = "A given name for the compute instance production VM"
  type        = string
}

variable "vm_mgmt_name" {
  description = "A given name for the compute instance management VM"
  type        = string
}

variable "vm_prod_machine_type" {
  description = "Machine type for production VM running Wordpress (e2-standard-2 recommended for moderate traffic)"
  type        = string
  default     = "e2-standard-2"
}

variable "vm_mgmt_machine_type" {
  description = "Machine type for management VM running CloudSQL Auth Proxy only (e2-medium sufficient for admin access workloads)"
  type        = string
  default     = "e2-medium"
}

variable "vm_boot_disk_image" {
  description = "Boot disk image for production and management VM"
  type        = string
  default     = "debian-cloud/debian-12"
}


/* CloudSQL database configuration variables, including instance name, region, database version, 
  tier, machine type, edition, availability type, disk type, and disk size*/
variable "db_instance_name" {
  description = "Name for the CloudSQL production database"
  type        = string
}

variable "db_region" {
  description = "Region for the CloudSQL production database"
  type        = string
  default     = "us-central1"
}

variable "db_version" {
  description = "CloudSQL database engine PostgreSQL"
  type        = string
  default     = "POSTGRES_17"
}

variable "db_tier" {
  description = "Machine type for CloudSQL instance (db-custom-4-16384, 4 vCPU, 16 GB RAM for moderate traffic)"
  type        = string
  default     = "db-custom-4-16384"
}

variable "db_edition" {
  description = "Edition for the CloudSQL instance (ENTERPRISE sufficient for general machine usage)"
  type        = string
  default     = "ENTERPRISE"
}

variable "db_availability_type" {
  description = "Availability type for CloudSQL instance (REGIONAL for high-availability)"
  type        = string
  default     = "REGIONAL"
}

variable "db_disk_type" {
  description = "value"
  type        = string
  default     = "PD_SSD"
}

variable "db_disk_size" {
  description = "Initial disk size for CloudSQL instance (100 GB recommended for moderate traffic)"
  type        = string
  default     = "100GB"

}

# VPC and subnet configuration variables for production and management networks, including names, regions, and IP CIDR ranges.
variable "vpc_prod_name" {
  description = "Main name for the VPC production network"
  type        = string
}

variable "subnet_prod_name" {
  description = ""
  type        = string
}

variable "subnet_prod_region" {
  description = "value"
  type        = string
  default     = "us-central1"

}

variable "subnet_prod_ip_cidr_range" {
  description = "value"
  type        = string
  default     = "10.0.0.0/24"
}


variable "vpc_mgmt_name" {
  description = "Main name for the VPC management network"
  type        = string
}

variable "subnet_mgmt_name" {
  description = "value"
  type        = string

}

variable "subnet_mgmt_region" {
  description = "value"
  type        = string
  default     = "us-central1"

}

variable "subnet_mgmt_ip_cidr_range" {
  description = "value"
  type        = string
  default     = "192.168.1.0/24"
}

# Variables for Cloud Function configuration, including function name and base name for backup storage bucket.
variable "db_backup_fn_name" {
  description = "Name for the CloudSQL backup function"
  type        = string
  default     = "wordpress-fn-db-backup-prod"
}

variable "backup_bucket_base_name" {
  description = "value"
  type        = string
  default     = "wordpress-bucket-prod"
}

variable "external_lb_proxy_subnet_cidr" {
  description = "IP CIDR range for the external load balancer proxy subnet"
  type        = string
  default     = "10.0.1.0/24"
}

locals {
  full_bucket_name = "${var.backup_bucket_base_name}-${var.project_id}"
}




