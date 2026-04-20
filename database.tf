# Terraform configuration for Google Cloud SQL resources

/* Database instance configuration for CloudSQL, including settings for machine type, 
disk size, backup configuration, and deletion protection. The lifecycle block is used 
to ignore changes to disk size after the initial creation of the instance, 
allowing for manual resizing without triggering a Terraform update. */
resource "google_sql_database_instance" "main" {
  depends_on          = [google_project_service.gcp_services]
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

    ip_configuration {
      ipv4_enabled    = false
      private_network = module.vpc_prod.vpc_id
    }
  }

  lifecycle {
    ignore_changes = [disk_size]
  }

}

resource "google_sql_database" "wordpress_db" {
  name     = "wordpress"
  instance = google_sql_database_instance.main
}

resource "google_sql_user" "wordpress" {
  name     = "wordpress"
  instance = google_sql_database_instance.main
  password = random_password.db_password.result
}
