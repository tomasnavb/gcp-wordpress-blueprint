resource "google_project_service" "secretmanager" {
  depends_on         = [google_project_service.gcp_services]
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# Database password secret
resource "google_secret_manager_secret" "db_password" {
  secret_id           = "database-password"
  project             = var.project_id
  deletion_protection = true

  replication {
    auto {}
  }

  labels = {
    application = "wordpress-instances"
  }

  depends_on = [google_project_service.secretmanager]
}

# Generate a random password for the database
resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>:?"
}

# Store the password as a secret version
resource "google_secret_manager_secret_version" "db_password" {
  secret = google_secret_manager_secret.db_password.id
  secret_data = jsonencode({
    db_name                  = google_sql_database.wordpress_db.name
    db_user                  = google_sql_user.wordpress.name
    db_password              = random_password.db_password.result
    db_host                  = google_sql_database_instance.main.private_ip_address
    instance_connection_name = google_sql_database_instance.main.connection_name
  })
}
