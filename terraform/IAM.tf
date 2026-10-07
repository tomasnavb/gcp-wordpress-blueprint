# IAM for the WordPress environment.
#
# Layout:
#   1. Service accounts
#   2. Custom roles
#   3. Bindings, grouped by who receives the access:
#        3.1 Operator (human user)
#        3.2 Management VM
#        3.3 Production VMs (MIG)
#        3.4 Cloud SQL instance
#        3.5 Backup function — runtime
#        3.6 Backup function — build
#        3.7 Cloud Scheduler
#
# The "serviceAccount:<email>" member strings are defined in locals.tf (local.service_accounts).

# ==========================================
# 1. SERVICE ACCOUNTS
# ==========================================

# Identity of the management VM.
resource "google_service_account" "mgmt_vm" {
  account_id   = "mgmt-vm-sa"
  display_name = "Service Account for the management VM (Cloud SQL admin access)"
}

# Identity of the WordPress instances in the MIG.
resource "google_service_account" "prod_vm" {
  account_id   = "prod-vm-sa"
  display_name = "Service Account for production WordPress VM instances"
}

# Runtime identity of the backup Cloud Function: what the function code runs as.
resource "google_service_account" "cloudsql_backup_fn" {
  account_id   = "cloudsql-backup-fn-sa"
  display_name = "Service Account for the CloudSQL backup Cloud Function"
}

# Build identity of the backup Cloud Function: what Cloud Build runs as when it builds
# the function's container image. Replaces the Compute Engine default SA.
resource "google_service_account" "cloudsql_backup_fn_build" {
  account_id   = "cloudsql-backup-fn-build-sa"
  display_name = "Service Account for building the CloudSQL backup Cloud Function"
}

# Identity Cloud Scheduler uses to call the backup Cloud Function.
resource "google_service_account" "scheduler_fn_invoker" {
  account_id   = "scheduler-fn-invoker-sa"
  display_name = "Service Account for Cloud Scheduler to invoke the CloudSQL backup function"
}

# ==========================================
# 2. CUSTOM ROLES
# ==========================================

# Only the Cloud SQL permissions the backup function needs: read the instance,
# start an export and create on-demand backups.
resource "google_project_iam_custom_role" "fn_db_backup" {
  role_id     = "dbBackupRole"
  title       = "Database Backup Role"
  description = "Custom role for Cloud Function to backup CloudSQL database to Cloud Storage"
  permissions = [
    "cloudsql.instances.get",
    "cloudsql.instances.list",
    "cloudsql.instances.export",
    "cloudsql.backupRuns.create",
    "cloudsql.backupRuns.export",
    "cloudsql.backupRuns.list",
    "cloudsql.backupRuns.get",
  ]
}

# ==========================================
# 3. BINDINGS
# ==========================================

# ------------------------------------------
# 3.1 Operator (human user)
# ------------------------------------------

# Open IAP tunnels, used for SSH into VMs that have no public IP.
resource "google_project_iam_member" "iap_tunnel_access" {
  project = var.project_id
  role    = "roles/iap.tunnelResourceAccessor"
  member  = "user:${var.iap_user_email}"
}

# ------------------------------------------
# 3.2 Management VM
# ------------------------------------------

# Manage Cloud SQL instances (admin tasks, maintenance scripts).
resource "google_project_iam_member" "cloudsql_editor" {
  project = var.project_id
  role    = "roles/cloudsql.editor"
  member  = local.service_accounts.mgmt
}

# Describe and list Compute instances (required by gcloud compute ssh).
resource "google_project_iam_member" "mgmt_compute_viewer" {
  project = var.project_id
  role    = "roles/compute.viewer"
  member  = local.service_accounts.mgmt
}

# OS Login with sudo on the instances it connects to.
resource "google_project_iam_member" "mgmt_os_admin_login" {
  project = var.project_id
  role    = "roles/compute.osAdminLogin"
  member  = local.service_accounts.mgmt
}

# Open IAP tunnels to the production instances.
resource "google_project_iam_member" "mgmt_iap_tunnel_access" {
  project = var.project_id
  role    = "roles/iap.tunnelResourceAccessor"
  member  = local.service_accounts.mgmt
}

# Act as the production VM SA. OS Login requires this to SSH into an instance
# that runs as that service account. Scoped to that one SA, not the project.
resource "google_service_account_iam_member" "mgmt_ssh_to_prod" {
  service_account_id = google_service_account.prod_vm.name
  role               = "roles/iam.serviceAccountUser"
  member             = local.service_accounts.mgmt
}

# ------------------------------------------
# 3.3 Production VMs (MIG)
# ------------------------------------------

# Read the WordPress database secrets. One binding per secret, not project-wide.
resource "google_secret_manager_secret_iam_member" "prod_vm_secret_access" {
  for_each  = google_secret_manager_secret.wordpress_secrets
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  secret_id = each.value.id
  member    = local.service_accounts.prod
}

# Write logs to Cloud Logging.
resource "google_project_iam_member" "prod_vm_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = local.service_accounts.prod
}

# ------------------------------------------
# 3.4 Cloud SQL instance
# ------------------------------------------

# The instance's own Google-managed SA writes export files to the backup bucket.
resource "google_storage_bucket_iam_member" "bucket_admin" {
  bucket = google_storage_bucket.cloudsql_backups.name
  role   = "roles/storage.admin"
  member = local.service_accounts.sql_instance
}

# ------------------------------------------
# 3.5 Backup function — runtime
# ------------------------------------------

# Use the custom backup role defined in section 2.
resource "google_project_iam_member" "cloudsql_backup_fn_role_binding" {
  project = var.project_id
  role    = google_project_iam_custom_role.fn_db_backup.id
  member  = local.service_accounts.fn
}

# ------------------------------------------
# 3.6 Backup function — build
#
# Deploying a Cloud Function v2 starts a separate Cloud Build that builds the container image.
# That build reads the source zip, pushes the image to Artifact Registry and writes build logs.
# ------------------------------------------

# Read the function source zip from the scripts bucket.
resource "google_storage_bucket_iam_member" "fn_build_source_viewer" {
  bucket = google_storage_bucket.scripts.name
  role   = "roles/storage.objectViewer"
  member = local.service_accounts.fn_build
}

# Push and pull images in Artifact Registry. Project-level because the gcf-artifacts repository
# is created by Cloud Functions on the first deploy and does not exist before it.
resource "google_project_iam_member" "fn_build_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = local.service_accounts.fn_build
}

# Write build logs to Cloud Logging.
resource "google_project_iam_member" "fn_build_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = local.service_accounts.fn_build
}

# ------------------------------------------
# 3.7 Cloud Scheduler
# ------------------------------------------

# Invoke the backup function. Cloud Functions v2 runs on Cloud Run, so roles/run.invoker
# is bound on the underlying Cloud Run service, not on the Cloud Functions resource.
resource "google_cloud_run_v2_service_iam_member" "fn_invoker_binding" {
  project  = var.project_id
  location = google_cloudfunctions2_function.db_backup_fn.location
  name     = google_cloudfunctions2_function.db_backup_fn.name
  role     = "roles/run.invoker"
  member   = local.service_accounts.scheduler
}
