# IAM for the WordPress environment.
#
# Layout:
#   1. Service accounts
#   2. Custom roles
#   3. Bindings, grouped by who receives the access:
#        3.1 Operator (human user)
#        3.2 Production VMs (MIG)
#        3.3 Cloud SQL instance
#        3.4 Backup function — runtime
#        3.5 Backup function — build
#        3.6 Cloud Scheduler
#
# The "serviceAccount:<email>" member strings are defined in locals.tf (local.service_accounts).

# ==========================================
# 1. SERVICE ACCOUNTS
# ==========================================

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

# Only the Cloud SQL permissions the backup function needs: read the instance and start an export.
resource "google_project_iam_custom_role" "fn_db_backup" {
  role_id     = "dbBackupRole"
  title       = "Database Backup Role"
  description = "Custom role for Cloud Function to backup CloudSQL database to Cloud Storage"
  permissions = [
    "cloudsql.instances.get",
    "cloudsql.instances.list",
    "cloudsql.instances.export",
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
# 3.2 Production VMs (MIG)
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

# Read and write WordPress uploads in the statics bucket, mounted with Cloud Storage FUSE.
# roles/storage.objectUser on that bucket only: create, read and delete objects, nothing else.
resource "google_storage_bucket_iam_member" "prod_vm_statics_user" {
  bucket = google_storage_bucket.statics.name
  role   = "roles/storage.objectUser"
  member = local.service_accounts.prod
}

# IAM bindings take time to propagate. An instance that boots seconds after the bindings
# above are created cannot read its secrets or write logs yet, and its startup script fails.
# The MIG depends on this wait instead of on the bindings directly (see compute.tf).
resource "time_sleep" "prod_vm_iam_propagation" {
  create_duration = "120s"

  depends_on = [
    google_secret_manager_secret_iam_member.prod_vm_secret_access,
    google_project_iam_member.prod_vm_log_writer,
    google_storage_bucket_iam_member.prod_vm_statics_user,
  ]
}

# ------------------------------------------
# 3.3 Cloud SQL instance
# ------------------------------------------

# The instance's own Google-managed SA writes export files to the backup bucket.
resource "google_storage_bucket_iam_member" "bucket_admin" {
  bucket = google_storage_bucket.cloudsql_backups.name
  role   = "roles/storage.admin"
  member = local.service_accounts.sql_instance
}

# ------------------------------------------
# 3.4 Backup function — runtime
# ------------------------------------------

# Use the custom backup role defined in section 2.
resource "google_project_iam_member" "cloudsql_backup_fn_role_binding" {
  project = var.project_id
  role    = google_project_iam_custom_role.fn_db_backup.id
  member  = local.service_accounts.fn
}

# ------------------------------------------
# 3.5 Backup function — build
#
# Deploying a Cloud Function v2 starts a separate Cloud Build that builds the container image.
# That build reads the source zip, pushes the image to Artifact Registry and writes build logs.
# ------------------------------------------

# Read the function source from the bucket Cloud Functions builds from.
# Cloud Functions does not build from the scripts bucket: it first copies the zip to a bucket of its
# own, gcf-v2-sources-<project number>-<region>, and the build reads it there. That bucket is created
# on the first deploy, so the role cannot be bound on it beforehand and has to be project-level.
# The condition keeps it from reaching any other bucket, in particular the database backups.
resource "google_project_iam_member" "fn_build_gcf_sources_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = local.service_accounts.fn_build

  condition {
    title       = "gcf-v2-sources-buckets-only"
    description = "Limits the role to the source buckets created by Cloud Functions"
    expression  = "resource.name.startsWith(\"projects/_/buckets/gcf-v2-sources-\")"
  }
}

# Read the function source zip from the scripts bucket.
# Probably not needed: the build reads from the gcf-v2-sources bucket above. Kept until a deploy
# without it confirms that.
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

# IAM bindings are not effective the moment they are created: they take time to propagate.
# Without this wait the function build starts seconds after the bindings above and fails with
# "does not have permission to write logs" or "access to bucket denied", although the roles are
# already granted.
# The function depends on this resource instead of on the bindings directly.
resource "time_sleep" "fn_build_iam_propagation" {
  create_duration = "120s"

  depends_on = [
    google_project_iam_member.fn_build_gcf_sources_viewer,
    google_storage_bucket_iam_member.fn_build_source_viewer,
    google_project_iam_member.fn_build_artifact_writer,
    google_project_iam_member.fn_build_log_writer,
  ]
}

# ------------------------------------------
# 3.6 Cloud Scheduler
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
