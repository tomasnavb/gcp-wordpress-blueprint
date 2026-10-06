# IAM binding granting the operator IAP tunnel access for SSH into the management VM.
resource "google_project_iam_member" "iap_tunnel_access" {
  project = var.project_id
  role    = local.roles.iap_tunnel_accessor
  member  = "user:${var.iap_user_email}"
}

# IAM binding for the management VM SA to manage Cloud SQL instances (admin tasks, maintenance scripts).
resource "google_project_iam_member" "cloudsql_editor" {
  project = var.project_id
  role    = local.roles.cloudsql_editor
  member  = local.service_accounts.mgmt
}

# IAM binding for the Cloud SQL instance SA to write backups to the Cloud Storage bucket.
resource "google_storage_bucket_iam_member" "bucket_admin" {
  bucket = google_storage_bucket.cloudsql_backups.name
  role   = local.roles.bucket_admin
  member = local.service_accounts.sql_instance
}

# IAM binding for the Cloud Run Functions running the DB backups
resource "google_storage_bucket_iam_member" "db_backup_fn_binding" {
  bucket = google_storage_bucket.scripts.name
  role   = "roles/storage.objectViewer"
  member = local.service_accounts.fn
}

# IAM binding for the backup Cloud Function SA to use the custom CloudSQL backup role.
resource "google_project_iam_member" "cloudsql_backup_fn_role_binding" {
  project = var.project_id
  role    = google_project_iam_custom_role.fn_db_backup.id
  member  = local.service_accounts.fn
}

# IAM bindings granting the production VM SA access to all WordPress secrets in Secret Manager.
resource "google_secret_manager_secret_iam_member" "prod_vm_secret_access" {
  for_each  = google_secret_manager_secret.wordpress_secrets
  project   = var.project_id
  role      = local.roles.secret_manager_accessor
  secret_id = each.value.id
  member    = local.service_accounts.prod
}

# IAM binding allowing production VM instances to write logs to Cloud Logging.
resource "google_project_iam_member" "prod_vm_log_writer" {
  project = var.project_id
  role    = local.roles.log_writer
  member  = local.service_accounts.prod
}

# IAM binding allowing the management VM SA to describe and list Compute instances (required by gcloud compute ssh).
resource "google_project_iam_member" "mgmt_compute_viewer" {
  project = var.project_id
  role    = local.roles.compute_viewer
  member  = local.service_accounts.mgmt
}

# IAM binding allowing the management VM SA to use OS Login with sudo privilege for SSH access to production instances.
resource "google_project_iam_member" "mgmt_os_admin_login" {
  project = var.project_id
  role    = local.roles.os_admin_login
  member  = local.service_accounts.mgmt
}

# IAM binding allowing the management VM SA to SSH into production instances (impersonate prod-vm-sa).
resource "google_service_account_iam_member" "mgmt_ssh_to_prod" {
  service_account_id = google_service_account.prod_vm.name
  role               = "roles/iam.serviceAccountUser"
  member             = local.service_accounts.mgmt
}

# IAM binding allowing the management VM SA to open IAP tunnels to production instances.
resource "google_project_iam_member" "mgmt_iap_tunnel_access" {
  project = var.project_id
  role    = local.roles.iap_tunnel_accessor
  member  = local.service_accounts.mgmt
}

# IAM binding for the Cloud Scheduler SA to invoke the backup Cloud Function.
# Cloud Functions v2 runs on Cloud Run — roles/run.invoker must be bound on the
# underlying Cloud Run service, not on the Cloud Functions resource.
resource "google_cloud_run_v2_service_iam_member" "fn_invoker_binding" {
  project  = var.project_id
  location = google_cloudfunctions2_function.db_backup_fn.location
  name     = google_cloudfunctions2_function.db_backup_fn.name
  role     = local.roles.fn_invoker
  member   = local.service_accounts.scheduler
}

# Management VM service account.
resource "google_service_account" "mgmt_vm" {
  account_id   = "mgmt-vm-sa"
  display_name = "Service Account for the management VM (Cloud SQL admin access)"
}

# Production VM service account.
resource "google_service_account" "prod_vm" {
  account_id   = "prod-vm-sa"
  display_name = "Service Account for production WordPress VM instances"
}

# Cloud Scheduler service account to invoke the backup Cloud Function.
resource "google_service_account" "scheduler_fn_invoker" {
  account_id   = "scheduler-fn-invoker-sa"
  display_name = "Service Account for Cloud Scheduler to invoke the CloudSQL backup function"
}

# Cloud Function service account to manage Cloud SQL backups.
resource "google_service_account" "cloudsql_backup_fn" {
  account_id   = "cloudsql-backup-fn-sa"
  display_name = "Service Account for the CloudSQL backup Cloud Function"
}

# Custom IAM role for the backup Cloud Function with least-privilege CloudSQL backup permissions.
resource "google_project_iam_custom_role" "fn_db_backup" {
  role_id     = local.roles.custom_db_backup_role.id
  title       = local.roles.custom_db_backup_role.title
  description = local.roles.custom_db_backup_role.description
  permissions = local.roles.custom_db_backup_role.permissions
}
