resource "google_secret_manager_secret" "wordpress_secrets" {
  for_each  = local.secrets
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

resource "google_secret_manager_secret_version" "wordpress_secrets" {
  for_each    = local.secrets
  secret      = google_secret_manager_secret.wordpress_secrets[each.key].id
  secret_data = each.value
}
