# Secret containers: the secret itself, without a value. All five, the password included, so the
# bindings in IAM.tf that iterate over them keep covering the password.
resource "google_secret_manager_secret" "wordpress_secrets" {
  for_each  = toset(local.secret_names)
  secret_id = each.key
  project   = var.project_id

  replication {
    auto {}
  }

  labels = {
    application = "wordpress"
  }

  depends_on = [google_project_service.gcp_services]
}

# Values of the secrets that are not sensitive (names, host, connection string).
resource "google_secret_manager_secret_version" "wordpress_secrets" {
  for_each    = local.secret_values
  secret      = google_secret_manager_secret.wordpress_secrets[each.key].id
  secret_data = each.value
}

# Value of the database password, written with a write-only argument so it is not stored in the
# state or in a saved plan. It is written when the secret version is created and again only when
# var.db_password_version changes; the ephemeral value generated on other runs is discarded.
resource "google_secret_manager_secret_version" "db_password" {
  secret = google_secret_manager_secret.wordpress_secrets[local.db_password_secret_name].id

  secret_data_wo         = ephemeral.random_password.db_password.result
  secret_data_wo_version = var.db_password_version
}
