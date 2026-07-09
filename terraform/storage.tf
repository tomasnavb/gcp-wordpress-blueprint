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

}

# Storage bucket for Cloud Function source code
resource "google_storage_bucket" "scripts" {
  depends_on    = [google_project_service.gcp_services]
  name          = local.scripts_bucket_name
  location      = "EU"
  storage_class = "STANDARD"

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
