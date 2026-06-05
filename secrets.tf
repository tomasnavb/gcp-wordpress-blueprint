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

  depends_on = [google_project_service.gcp_services]
}

# Store the password as a secret version
resource "google_secret_manager_secret_version" "db_password" {
  secret = google_secret_manager_secret.db_password.secret_id
  secret_data = jsonencode({
    db_name                  = var.db_name
    db_user                  = var.db_user
    db_password              = random_password.db_password.result
    db_host                  = google_sql_database_instance.main.private_ip_address
    instance_connection_name = google_sql_database_instance.main.connection_name
  })
}
