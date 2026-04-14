# Terraform configuration for Google Cloud SQL resources

/* Database instance configuration for CloudSQL, including settings for machine type, 
disk size, backup configuration, and deletion protection. The lifecycle block is used 
to ignore changes to disk size after the initial creation of the instance, 
allowing for manual resizing without triggering a Terraform update. */
resource "google_sql_database_instance" "main" {
  name                = var.db_instance_name
  region              = var.db_region
  database_version    = var.db_version
  deletion_protection = true

  settings {
    tier              = var.db_tier
    edition           = var.db_edition
    availability_type = var.db_availability_type
    disk_autoresize   = true
    disk_type         = var.db_disk_type
    disk_size         = var.db_disk_size
  }

  lifecycle {
    ignore_changes = [disk_size]
  }

}
