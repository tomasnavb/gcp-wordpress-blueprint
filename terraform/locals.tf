locals {
  # Service accounts
  service_accounts = {
    prod         = "serviceAccount:${google_service_account.prod_vm.email}"
    sql_instance = "serviceAccount:${google_sql_database_instance.main.service_account_email_address}"
    fn           = "serviceAccount:${google_service_account.cloudsql_backup_fn.email}"
    fn_build     = "serviceAccount:${google_service_account.cloudsql_backup_fn_build.email}"
    scheduler    = "serviceAccount:${google_service_account.scheduler_fn_invoker.email}"
  }

  # Virtual machines
  disk_size_gb = 10
  disk_type    = "pd-standard"

  # Cloud Storage
  db_backup_bucket_name = "${var.db_backup_bucket_base_name}-${var.project_id}"
  scripts_bucket_name   = "${var.scripts_bucket_base_name}-${var.project_id}"

  # Statics bucket: content WordPress writes at runtime, shared by every instance (today, uploads).
  # A fixed name and not a variable on purpose. The bucket has one specific job, and
  # configs/destroy.sh builds the same name to empty it: changing it here alone would break that.
  statics_bucket_name = "wordpress-statics-${var.project_id}"

  # Folder of the statics bucket that holds the uploads. Defined once here: Terraform creates the
  # folder from it (storage.tf) and passes it to the instances as metadata (compute.tf), and the
  # startup script mounts whatever folder it is given. No trailing slash.
  statics_uploads_folder = "uploads"

  # Access settings shared by every bucket, set here so no bucket can drift from them:
  # - uniform bucket-level access: permissions come from IAM only, no per-object ACLs.
  #   IAM conditions on buckets (IAM.tf, function build SA) require it.
  # - public access prevention: the bucket and its objects can never be made public.
  bucket_uniform_access           = true
  bucket_public_access_prevention = "enforced"

  # Cloud Scheduler
  scheduler_export_name        = "export-db-backup"
  scheduler_export_description = "Cloud Scheduler job to trigger Cloud Function for CloudSQL export backup"
  scheduler_export_schedule    = "0 0 * * *" # Daily at midnight
  scheduler_export_backup_type = "export"    # Request body type the function expects

  # Secret Manager
  # The secret names are read by name in terraform/scripts/startup-prod.sh:
  # do not rename one here without changing it there.

  # Values that are not sensitive. They are stored as regular secret versions.
  secret_values = {
    "wordpress-db-name"                = var.db_name
    "wordpress-db-user"                = var.db_user
    "wordpress-db-host"                = google_sql_database_instance.main.private_ip_address
    "wordpress-db-instance-connection" = google_sql_database_instance.main.connection_name
  }

  # The database password is not in the map above on purpose: it is an ephemeral value, which
  # cannot go through a for_each, and it is written with a write-only argument (secrets.tf).
  db_password_secret_name = "wordpress-db-password"

  # Every secret container: the ones above plus the password. IAM.tf grants access over all of them.
  secret_names = concat(keys(local.secret_values), [local.db_password_secret_name])

}
