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

  uniform_bucket_level_access = local.bucket_uniform_access
  public_access_prevention    = local.bucket_public_access_prevention

}

# Storage bucket for Cloud Function source code
resource "google_storage_bucket" "scripts" {
  depends_on    = [google_project_service.gcp_services]
  name          = local.scripts_bucket_name
  location      = "EU"
  storage_class = "STANDARD"

  uniform_bucket_level_access = local.bucket_uniform_access
  public_access_prevention    = local.bucket_public_access_prevention

}

# Statics bucket: the content WordPress writes at runtime, kept outside the instances so they stay
# stateless. It is laid out with one folder per kind of content. Today there is one, uploads/
# (media): every instance mounts that folder at wp-content/uploads with Cloud Storage FUSE
# (gcsfuse, --only-dir), so a file uploaded through one instance is visible from all of them, and
# survives when the MIG replaces an instance.
#
# - The name is fixed in locals.tf, not a variable (see the comment there).
# - Same region as the instances, for latency and to avoid inter-region traffic.
# - force_destroy = false and protected in cloudbuild/scripts/check_destructive.py: it holds data.
#   Empty it with configs/destroy.sh before terraform destroy.
# - Versioning keeps deleted or overwritten files for 30 days.
# - No retention policy: Cloud Storage FUSE cannot write to a bucket that has one.
resource "google_storage_bucket" "statics" {
  depends_on    = [google_project_service.gcp_services]
  name          = local.statics_bucket_name
  location      = var.subnet_prod_region
  storage_class = "STANDARD"
  force_destroy = false

  uniform_bucket_level_access = local.bucket_uniform_access
  public_access_prevention    = local.bucket_public_access_prevention

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

# Marker object that makes uploads/ exist as a folder in the statics bucket.
# Cloud Storage has no real folders in a bucket like this one: a folder is an object whose name
# ends in "/". The instances mount only that folder (gcsfuse --only-dir), and gcsfuse does
# not create it on its own, so it has to exist before the first instance boots. --implicit-dirs
# does not cover this case: it infers a folder from the objects inside it, and a new bucket is empty.
# The provider requires non-empty content; it is ignored.
resource "google_storage_bucket_object" "uploads_folder" {
  bucket = google_storage_bucket.statics.name

  # The folder name comes from the same local that is passed to the instances as metadata, so the
  # folder created here and the folder they mount cannot differ.
  # The trailing slash is required: it is what makes the object a folder.
  name = "${local.statics_uploads_folder}/"

  content = " "
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
