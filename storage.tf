# Terraform configuration for Google Cloud Storage resources

# Bucket for CloudSQL database backups with lifecycle rule to delete objects after 90 days
resource "google_storage_bucket" "cloudsql_backups" {
  name          = local.full_bucket_name
  location      = "US"
  storage_class = "NEARLINE"

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

}

# Storage bucket for Cloud Function source code
resource "google_storage_bucket" "scripts" {
  name          = "python-scripts"
  location      = "US"
  storage_class = "ARCHIVE"

}

# Archive the Cloud Function source code
data "archive_file" "function_zip" {
  type        = "zip"
  source_dir  = "./functions/db-backup"
  output_path = "./tmp/db-backup.zip"

}

# Upload the Cloud Function source code to the storage bucket
resource "google_storage_bucket_object" "function_code" {
  bucket = google_storage_bucket.scripts.name
  name   = "backup-prod.zip"
  source = data.archive_file.function_zip.output_path


}
