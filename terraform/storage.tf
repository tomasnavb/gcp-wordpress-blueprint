# Terraform configuration for Google Cloud Storage resources

# Bucket for CloudSQL database backups with lifecycle rule to delete objects after 90 days
resource "google_storage_bucket" "cloudsql_backups" {
  depends_on    = [google_project_service.gcp_services]
  name          = local.db_backup_bucket_name
  location      = "EU"
  storage_class = "COLDLINE"
  force_destroy = false
  versioning {
    enabled = true
  }

  # Delete objects older than 90 days
  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  # Delete noncurrent versions of objects after 7 days, keeping only the 2 most recent versions
  lifecycle_rule {
    condition {
      num_newer_versions = 2
      age                = 7
    }
    action {
      type = "Delete"
    }
  }

  uniform_bucket_level_access = true

}

# Storage bucket for Cloud Function source code
resource "google_storage_bucket" "scripts" {
  depends_on    = [google_project_service.gcp_services]
  name          = local.scripts_bucket_name
  location      = "EU"
  storage_class = "STANDARD"

  uniform_bucket_level_access = true

}

# Bucket for WordPress uploads (media), mounted on every instance at wp-content/uploads with
# Cloud Storage FUSE (gcsfuse). Uploads are the only content WordPress writes at runtime; keeping
# them here makes the instances stateless: a file uploaded through one instance is visible from all
# of them, and survives when the MIG replaces an instance.
#
# - Same region as the instances, for latency and to avoid inter-region traffic.
# - force_destroy = false and protected in cloudbuild/scripts/check_destructive.py: it holds data.
#   Empty it with configs/destroy.sh before terraform destroy.
# - Versioning keeps deleted or overwritten files for 30 days.
# - No retention policy: Cloud Storage FUSE cannot write to a bucket that has one.
resource "google_storage_bucket" "uploads" {
  depends_on    = [google_project_service.gcp_services]
  name          = local.uploads_bucket_name
  location      = var.subnet_prod_region
  storage_class = "STANDARD"
  force_destroy = false

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  # Delete noncurrent versions 30 days after they stop being the live version
  lifecycle_rule {
    condition {
      days_since_noncurrent_time = 30
    }
    action {
      type = "Delete"
    }
  }
}

# Archive the Cloud Function source code
data "archive_file" "function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/functions/db-backup"
  output_path = "${path.module}/tmp/db_backup.zip"

}

# Upload the Cloud Function source code to the storage bucket
resource "google_storage_bucket_object" "function_code" {
  bucket = google_storage_bucket.scripts.name
  name   = "backup-prod-${data.archive_file.function_zip.output_md5}.zip"
  source = data.archive_file.function_zip.output_path


}
