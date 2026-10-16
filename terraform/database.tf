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
      private_network = module.vpc.network_id
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

# ==========================================
# DATABASE PASSWORD
#
# The password never reaches the Terraform state or a saved plan. It flows like this:
#
#   ephemeral random_password ──► Secret Manager ──(ephemeral read)──► Cloud SQL user
#        generated per run        secret_data_wo                        password_wo
#
# - Ephemeral resources exist only while Terraform runs: their values are used and discarded.
# - Write-only arguments (*_wo) are sent to the API and not stored. Terraform cannot tell whether
#   they changed, so each one has a *_wo_version: the value is sent again only when it changes.
# - Secret Manager is the source of truth. The SQL user takes the password from the secret, not
#   from the generator, so both always hold the same value, even if an apply fails halfway.
#
# A new random value is generated on every run and thrown away unless var.db_password_version
# changes. Raising that variable rotates the password (see the README).
# ==========================================

# Generates a candidate password on every run. Not stored anywhere by itself.
ephemeral "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>:?"
}

# Reads the password back from Secret Manager for the SQL user. An ephemeral block, not a data
# source: a data source would store the value in the state.
ephemeral "google_secret_manager_secret_version" "db_password" {
  secret  = google_secret_manager_secret_version.db_password.secret
  version = google_secret_manager_secret_version.db_password.version
}

# Main database user for the WordPress application
resource "google_sql_user" "wordpress_app_user" {
  name     = var.db_user
  instance = google_sql_database_instance.main.name

  password_wo         = ephemeral.google_secret_manager_secret_version.db_password.secret_data
  password_wo_version = var.db_password_version
}
