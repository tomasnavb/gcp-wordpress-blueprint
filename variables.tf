/* Variables for Terraform configuration of a WordPress site on Google Cloud, including project settings, 
compute instance configurations, CloudSQL database settings, VPC and subnet configurations, and Cloud Function 
settings for database backups. */

###############################################################################
# PROJECT CONFIGURATION
###############################################################################

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

###############################################################################
# NETWORKING CONFIGURATION
###############################################################################

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


###############################################################################
# COMPUTE ENGINE CONFIGURATION
###############################################################################

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

###############################################################################
# CLOUDSQL INSTANCE CONFIGURATION
###############################################################################

variable "instance_name" {
  description = "Name for the CloudSQL production database"
  type        = string
}

variable "instance_region" {
  description = "Region for the CloudSQL production database"
  type        = string
  default     = "us-central1"
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

###############################################################################
# DATABASE CONFIGURATION
###############################################################################

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

###############################################################################
# CLOUD RUN FUNCTIONS CONFIGURATION
###############################################################################

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
  default     = "europe-west8"
}

variable "function_timeout_sec" {
  description = "Timeout for the CloudSQL backup function in seconds"
  type        = number
  default     = 600
}

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


variable "external_lb_proxy_subnet_cidr" {
  description = "IP CIDR range for the external load balancer proxy subnet"
  type        = string
  default     = "10.0.1.0/24"
}

###############################################################################
# LOCALS CONFIGURATION
###############################################################################

locals {
  # Roles
  roles = {
    iap_tunnel_accessor     = "roles/iap.tunnelResourceAccessor"
    cloudsql_editor         = "roles/cloudsql.editor"
    bucket_admin            = "roles/storage.admin"
    secret_manager_accessor = "roles/secretmanager.secretAccessor"
    fn_invoker              = "roles/cloudfunctions.invoker"
    custom_db_backup_role = {
      id          = "dbBackupRole"
      title       = "Database Backup Role"
      description = "Custom role for Cloud Function to backup CloudSQL database to Cloud Storage"
      permissions = [
        "cloudsql.instances.get",
        "cloudsql.instances.list",
        "cloudsql.backupRuns.create",
        "cloudsql.backupRuns.list",
        "cloudsql.backupRuns.get"
      ]
    }
  }

  # Service accounts
  service_accounts = {
    mgmt         = "serviceAccount:${google_service_account.mgmt_vm.email}"
    prod         = "serviceAccount:${google_service_account.prod_vm.email}"
    sql_instance = "serviceAccount:${google_sql_database_instance.main.service_account_email_address}"
    fn           = "serviceAccount:${google_service_account.cloudsql_backup_fn.email}"
    scheduler    = "serviceAccount:${google_service_account.scheduler_fn_invoker.email}"
  }

  # Virtual machines
  vm_prod_startup_script_path = "${path.module}/scripts/startup-prod.sh"
  vm_mgmt_startup_script_path = "${path.module}/scripts/startup-mgmt.sh"

  # Cloud Storage
  db_backup_bucket_name = "${var.db_backup_bucket_base_name}-${var.project_id}"
  scripts_bucket_name   = "${var.scripts_bucket_base_name}-${var.project_id}"

  # Cloud Run Functions
  function_runtime     = "python311"
  function_entry_point = "run_backup"

  # CloudSQL
  enable_instance_external_ip = false
  prevent_instance_destroy    = true

  # Cloud Scheduler
  scheduler_module               = "${path.module}/modules/cloud_scheduler"
  scheduler_export_name          = "export-db-backup"
  scheduler_export_description   = "Cloud Scheduler job to trigger Cloud Function for CloudSQL export backup"
  scheduler_export_schedule      = "0 0 * * *" # Daily at midnight
  scheduler_snapshot_name        = "snapshot-db-backup"
  scheduler_snapshot_description = "Cloud Scheduler job to trigger Cloud Function for CloudSQL snapshot backup"
  scheduler_snapshot_schedule    = "0 */4 * * *" # Every 4 hours
  scheduler_fn_backup_type       = { standard = "export", fast = "snapshot" }


}
