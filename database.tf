# Terraform configuration for Google Cloud SQL resources

/* Database instance configuration for CloudSQL, including settings for machine type, 
disk size, backup configuration, and deletion protection. The lifecycle block is used 
to ignore changes to disk size after the initial creation of the instance, 
allowing for manual resizing without triggering a Terraform update. */
resource "google_sql_database_instance" "main" {
  depends_on          = [google_project_service.gcp_services, google_service_networking_connection.private_connection]
  name                = var.instance_name
  region              = var.instance_region
  database_version    = var.instance_version
  deletion_protection = var.enable_instance_deletion_protection

  settings {
    tier              = var.instance_tier
    edition           = var.instance_edition
    availability_type = var.instance_availability_type
    disk_autoresize   = var.enable_instance_disk_autoresize
    disk_type         = var.instance_disk_type
    disk_size         = var.instance_disk_size_gb

    ip_configuration {
      ipv4_enabled    = local.enable_instance_external_ip
      private_network = module.vpc_prod.vpc_id
    }
  }

  lifecycle {
    prevent_destroy = local.prevent_instance_destroy
    ignore_changes  = [disk_size]
  }

}

# MySQL database for Wordpress site  
resource "google_sql_database" "wordpress_db" {
  name      = var.db_name
  instance  = google_sql_database_instance.main.self_link
  charset   = var.db_charset
  collation = var.db_collation
}

# Wordpress database user with random password
resource "google_sql_user" "wordpress_app_user" {
  name     = var.db_user
  instance = google_sql_database_instance.main.self_link
  password = random_password.db_password.result
}

# Generate a 32 lenght random password with special characters for the database user
resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>:?"
}
