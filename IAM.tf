# IAM.tf - IAM roles and service accounts for the WordPress site deployment on GCP
resource "google_project_iam_member" "iap_tunnel_access" {
  project = var.project_id
  role    = "roles/iap.tunnelResourceAccesor"
  member  = "user:tomy.brm@gmail.com"

}

resource "google_project_iam_member" "cloudsql_editor" {
  project = var.project_id
  role    = "role/cloudsql.editor"
  member  = "serviceAccount:${google_service_account.mgmt_vm.email}"

}

resource "google_storage_bucket_iam_member" "bucket_admin" {
  bucket = google_storage_bucket.main.self_link
  role   = "role/storage.bucketAdmin"
  member = "serviceAccount:${google_sql_database_instance.main.service_account_email_address}"

}

resource "google_project_iam_member" "cloudsql_backup_fn_role_binding" {
  project = var.project_id
  role    = google_project_iam_custom_role.fn_db_backup.self_link
  member  = "serviceAccount:${google_service_account.cloudsql_backup_fn.email}"

}

resource "google_cloudfunctions2_function_iam_member" "fn_invoker_binding" {
  project        = google_cloudfunctions2_function.db_backup_function.project
  location       = google_cloudfunctions2_function.db_backup_function.location
  cloud_function = google_cloudfunctions2_function.db_backup_function.self_link
  role           = "roles/cloudfunctions.invoker"
  member         = "serviceAccount:${google_service_account.scheduler_fn_invoker.email}"

}

resource "google_service_account" "mgmt_vm" {
  account_id   = "mgmt-vm-sa"
  display_name = "Service Account for the database connection of the mgmt VM"

}

resource "google_service_account" "scheduler_fn_invoker" {
  account_id   = "scheduler-fn-invoker-sa"
  display_name = "Service Account for Cloud Scheduler to invoke Cloud Function for CloudSQL backup"

}

resource "google_service_account" "cloudsql_backup_fn" {
  account_id   = "cloudsql-backup-fn-sa"
  display_name = "Service Account for Cloud Function to backup CloudSQL database to Cloud Storage"

}

# IAM Custom Role for Cloud Function to backup CloudSQL database to Cloud Storage
resource "google_project_iam_custom_role" "fn_db_backup" {
  role_id     = "dbBackupRole"
  title       = "Database Backup Role"
  description = "Custom role for Cloud Function to backup CloudSQL database to Cloud Storage"
  permissions = [
    "cloudsql.instances.get",
    "cloudsql.instances.list",
    "cloudsql.backupRuns.create",
    "cloudsql.backupRuns.list",
    "cloudsql.backupRuns.get",
    "storage.objects.create",
    "storage.objects.get",
    "storage.objects.list"
  ]
}



