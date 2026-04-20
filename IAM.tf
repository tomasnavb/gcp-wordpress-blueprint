# IAM bindings for the management VM to have access to IAP Tunnel.
resource "google_project_iam_member" "iap_tunnel_access" {
  project = var.project_id
  role    = "roles/iap.tunnelResourceAccesor"
  member  = "user:tomy.brm@gmail.com"

}

/* IAM binding for the management VM's service account to have the Cloud SQL Editor role, allowing it to manage 
Cloud SQL instances and connect to them securely. This is essential for the management VM to perform administrative 
tasks on the Cloud SQL database, such as running maintenance scripts or managing database users. */
resource "google_project_iam_member" "cloudsql_editor" {
  project = var.project_id
  role    = "role/cloudsql.editor"
  member  = "serviceAccount:${google_service_account.mgmt_vm.email}"

}

# IAM binding for the Cloud SQL instance's service account to have access to the Cloud Storage bucket for backups. 
resource "google_storage_bucket_iam_member" "bucket_admin" {
  bucket = google_storage_bucket.cloudsql_backups.self_link
  role   = "role/storage.bucketAdmin"
  member = "serviceAccount:${google_sql_database_instance.main.service_account_email_address}"

}

/* IAM binding for the Cloud Function that performs database backups to have the custom role with necessary 
permissions to manage Cloud SQL instances. */
resource "google_project_iam_member" "cloudsql_backup_fn_role_binding" {
  project = var.project_id
  role    = google_project_iam_custom_role.fn_db_backup.self_link
  member  = "serviceAccount:${google_service_account.cloudsql_backup_fn.email}"

}

# IAM binding for the production VM's service account to have access to the database password stored in Secret Manager. 
resource "google_secret_manager_secret_iam_member" "prod_vm_role_binding" {
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  secret_id = google_secret_manager_secret.db_password.id
  member    = "serviceAccount:${google_service_account.prod_vm.email}"

}

/* IAM binding for the Cloud Scheduler's service account to have the Cloud Functions Invoker role, allowing it to trigger 
the backup function according to the defined schedule. */
resource "google_cloudfunctions2_function_iam_member" "fn_invoker_binding" {
  project        = var.project_id
  location       = google_cloudfunctions2_function.db_backup_function.location
  cloud_function = google_cloudfunctions2_function.db_backup_function.self_link
  role           = "roles/cloudfunctions.invoker"
  member         = "serviceAccount:${google_service_account.scheduler_fn_invoker.email}"

}

# Management VM's service account.
resource "google_service_account" "mgmt_vm" {
  account_id   = "mgmt-vm-sa"
  display_name = "Service Account for the database connection of the mgmt VM"

}

# Production VM's service account.
resource "google_service_account" "prod_vm" {
  account_id   = "prod-vm-sa"
  display_name = "Service Account for the database connection of the mgmt VM"

}

# Cloud Scheduler service account to invoke the backup function.
resource "google_service_account" "scheduler_fn_invoker" {
  account_id   = "scheduler-fn-invoker-sa"
  display_name = "Service Account for Cloud Scheduler to invoke Cloud Function for CloudSQL backup"

}

# Cloud Function service account to manage Cloud SQL backups.
resource "google_service_account" "cloudsql_backup_fn" {
  account_id   = "cloudsql-backup-fn-sa"
  display_name = "Service Account for Cloud Function to backup CloudSQL database to Cloud Storage"

}

/* IAM Custom Role for Cloud Function for Cloud SQL backup, granting necessary permissions to manage 
Cloud SQL instances and backups. */
resource "google_project_iam_custom_role" "fn_db_backup" {
  role_id     = "dbBackupRole"
  title       = "Database Backup Role"
  description = "Custom role for Cloud Function to backup CloudSQL database to Cloud Storage"
  permissions = [
    "cloudsql.instances.get",
    "cloudsql.instances.list",
    "cloudsql.backupRuns.create",
    "cloudsql.backupRuns.list",
    "cloudsql.backupRuns.get"
  ]
}



