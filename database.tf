# Terraform configuration for Google Cloud SQL resources

/* Database instance configuration for CloudSQL, including settings for machine type, 
disk size, backup configuration, and deletion protection. The lifecycle block is used 
to ignore changes to disk size after the initial creation of the instance, 
allowing for manual resizing without triggering a Terraform update. */
resource "google_sql_database_instance" "main" {
  depends_on          = [google_project_service.gcp_services, google_service_networking_connection.private_connection]
  name                = var.sql_instance_name
  region              = var.sql_instance_region
  database_version    = var.sql_instance_version
  deletion_protection = var.enable_sql_instance_deletion_protection

  settings {
    tier              = var.sql_instance_tier
    edition           = var.sql_instance_edition
    availability_type = var.sql_instance_availability_type
    disk_autoresize   = var.enable_sql_instance_disk_autoresize
    disk_type         = var.sql_instance_disk_type
    disk_size         = var.sql_instance_disk_size_gb

    ip_configuration {
      ipv4_enabled    = false
      private_network = module.vpc_prod.vpc_id
    }
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [disk_size]
  }

}

resource "google_sql_database" "wordpress_db" {
  name      = var.db_name
  instance  = google_sql_database_instance.main.self_link
  charset   = var.db_charset
  collation = var.db_collation
}

resource "google_sql_user" "wordpress_app_user" {
  name     = var.db_user
  instance = google_sql_database_instance.main.self_link
  password = random_password.db_password.result
}
