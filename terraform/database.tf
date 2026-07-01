# Terraform configuration for Google Cloud SQL resources

/* CloudSQL database instance for MySQL. Regional configuration for high availability,  
disk autoresize preventing disk space exhaustion, and private networking for secure communication. */
resource "google_sql_database_instance" "main" {
  depends_on          = [google_project_service.gcp_services, google_service_networking_connection.private_connection]
  name                = var.instance_name
  region              = var.instance_region
  database_version    = "MYSQL_8_4"
  deletion_protection = false # Set to true in production environments to prevent accidental deletion of the database instance.

  settings {
    tier              = var.instance_tier
    edition           = var.instance_edition
    availability_type = var.instance_availability_type
    disk_autoresize   = true
    disk_type         = var.instance_disk_type
    disk_size         = var.instance_disk_size_gb

    backup_configuration {
      enabled            = true
      binary_log_enabled = true
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = module.vpc_prod.vpc_id
    }
  }

  lifecycle {
    prevent_destroy = false                   # Set to true in production environments to prevent accidental deletion of the database instance.
    ignore_changes  = [settings[0].disk_size] # Ignore changes to disk size to prevent unnecessary recreation of the instance when disk size is modified.
  }

}

# MySQL database required for Wordpress
resource "google_sql_database" "wordpress_db" {
  name      = var.db_name
  instance  = google_sql_database_instance.main.name
  charset   = var.db_charset
  collation = var.db_collation
}

# Main database user for Wordpress application with a randomly generated password stored in Secret Manager
resource "google_sql_user" "wordpress_app_user" {
  name     = var.db_user
  instance = google_sql_database_instance.main.name
  password = random_password.db_password.result
}

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>:?"
}
