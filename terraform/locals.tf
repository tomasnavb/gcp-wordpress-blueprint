locals {
  # Naming convention (docs: architecture style guide): [project]-[component]-[environment], lowercase,
  # hyphens only, region at the end of subnet names only, buckets prefixed with the project ID, service
  # accounts without environment (IAM.tf). Names are built here and not exposed as variables: each has
  # one job, and scripts outside Terraform rely on some of them (configs/setup.sh, configs/destroy.sh).
  name_prefix = "wp-blueprint"

  # Networking
  vpc_name                  = "${local.name_prefix}-vpc-${var.environment}"
  web_subnet_name           = "web-subnet-${var.environment}-${var.project_region}"
  build_subnet_name         = "build-subnet-${var.environment}-${var.project_region}"
  router_name               = "${local.name_prefix}-router-${var.environment}"
  nat_name                  = "${local.name_prefix}-nat-${var.environment}"
  psa_range_name            = "${local.name_prefix}-psa-range-${var.environment}"
  fw_iap_ssh_web_name       = "${local.name_prefix}-allow-iap-ssh-${var.environment}"
  fw_iap_ssh_build_name     = "${local.name_prefix}-allow-iap-ssh-build-${var.environment}"
  fw_deny_build_to_psa_name = "${local.name_prefix}-deny-build-to-psa-${var.environment}"

  # Network tags. The web tags are set on the instances (compute.tf), the build tag on the Packer VM
  # (packer/wordpress.pkr.hcl).
  # - backend-service: the load balancer firewall rule lets the Google front ends reach these instances.
  # - iap-ssh-access: SSH through IAP.
  backend_network_tag = "backend-service"
  web_ssh_network_tag = "iap-ssh-access"
  build_network_tag   = "packer-build"

  # Source range of IAP TCP forwarding, fixed by Google.
  iap_source_range = "35.235.240.0/20"

  # Compute: WordPress instances. The template name gets a suffix from GCP, so the environment cannot
  # be the last part of it.
  web_template_name_prefix = "${local.name_prefix}-web-tpl-${var.environment}-"
  web_mig_name             = "${local.name_prefix}-web-mig-${var.environment}"
  web_instance_base_name   = "${local.name_prefix}-web-${var.environment}"
  web_autoscaler_name      = "${local.name_prefix}-web-autoscaler-${var.environment}"
  web_health_check_name    = "${local.name_prefix}-web-hc-${var.environment}"

  # Golden image family built by Packer (packer/wordpress.pkr.hcl). No environment: one image family
  # per project, like the shared Artifact Registry of the style guide.
  image_family = "${local.name_prefix}-web"

  # Load balancer: the module builds every name as <prefix>-<component>-<environment>.
  lb_name_prefix = "${local.name_prefix}-lb"

  # Virtual machines
  disk_size_gb = 10
  disk_type    = "pd-standard"

  # Database
  db_instance_name = "${local.name_prefix}-db-${var.environment}"

  # Service accounts
  service_accounts = {
    web          = "serviceAccount:${google_service_account.web_vm.email}"
    sql_instance = "serviceAccount:${google_sql_database_instance.main.service_account_email_address}"
    fn           = "serviceAccount:${google_service_account.db_backup_fn.email}"
    fn_build     = "serviceAccount:${google_service_account.db_backup_build.email}"
    scheduler    = "serviceAccount:${google_service_account.scheduler_invoker.email}"
    # Created by configs/setup.sh, outside Terraform: built from its name, not from a resource.
    pipeline_plan = "serviceAccount:terraform-plan-sa@${var.project_id}.iam.gserviceaccount.com"
  }

  # Cloud Storage. Bucket names are unique across all of GCP, so they start with the project ID.
  # configs/destroy.sh builds the backup and uploads bucket names the same way to empty them:
  # change them here and there together.
  db_backup_bucket_name = "${var.project_id}-db-backups"
  fn_source_bucket_name = "${var.project_id}-fn-source"

  # Uploads bucket: the media WordPress writes at runtime, shared by every instance. It holds only the
  # uploads, under the same path WordPress serves them from, so a request for
  # /wp-content/uploads/2026/10/photo.jpg maps to the object wp-content/uploads/2026/10/photo.jpg.
  # Anything private goes in another bucket.
  uploads_bucket_name = "${var.project_id}-uploads"

  # Folder of the uploads bucket the instances mount. Defined once here: Terraform creates the folder
  # from it (storage.tf) and passes it to the instances as metadata (compute.tf), and the startup
  # script mounts whatever folder it is given. No trailing slash.
  uploads_folder = "wp-content/uploads"

  # Access settings shared by every bucket, set here so no bucket can drift from them:
  # - uniform bucket-level access: permissions come from IAM only, no per-object ACLs.
  #   IAM conditions on buckets (IAM.tf, function build SA) require it.
  # - public access prevention: the bucket and its objects can never be made public.
  bucket_uniform_access           = true
  bucket_public_access_prevention = "enforced"

  # Cloud Function and Cloud Scheduler
  db_backup_function_name      = "${local.name_prefix}-db-backup-fn-${var.environment}"
  scheduler_export_name        = "${local.name_prefix}-db-export-job-${var.environment}"
  scheduler_export_description = "Cloud Scheduler job to trigger Cloud Function for CloudSQL export backup"
  scheduler_export_schedule    = "0 0 * * *" # Daily at midnight
  scheduler_export_backup_type = "export"    # Request body type the function expects

  # Custom IAM role of the backup function. Role IDs accept no hyphens: the one exception to the naming
  # convention.
  db_backup_role_id = "wpBlueprintDbBackup"

  # Secret Manager. The startup script receives the names as instance metadata (compute.tf), so it
  # never hardcodes them.
  db_secret_names = {
    name     = "${local.name_prefix}-db-name-${var.environment}"
    user     = "${local.name_prefix}-db-user-${var.environment}"
    password = "${local.name_prefix}-db-password-${var.environment}"
    host     = "${local.name_prefix}-db-host-${var.environment}"
  }

  # Values that are not sensitive. They are stored as regular secret versions.
  secret_values = {
    (local.db_secret_names.name) = var.db_name
    (local.db_secret_names.user) = var.db_user
    (local.db_secret_names.host) = google_sql_database_instance.main.private_ip_address
  }

  # The database password is not in the map above on purpose: it is an ephemeral value, which
  # cannot go through a for_each, and it is written with a write-only argument (secrets.tf).
  db_password_secret_name = local.db_secret_names.password

  # Every secret container: the ones above plus the password. IAM.tf grants access over all of them.
  secret_names = concat(keys(local.secret_values), [local.db_password_secret_name])

  # The domains of var.domain_names as a list. The first one is the site address.
  domain_names = [for domain in split(",", var.domain_names) : trimspace(domain)]

  # Admin area and login of WordPress, always behind IAP in this project: a local, not a variable, so
  # configuration cannot turn it off. A fresh WordPress is installed by whoever completes
  # /wp-admin/install.php first, and bots try it within hours of a new domain appearing in
  # Certificate Transparency logs (devlog-2026-10-26-verification.md, E4). /wp-admin without the
  # trailing slash is listed on its own: /wp-admin/* does not match it.
  # admin-ajax.php stays public: themes and plugins call it from the public site.
  iap_protected_paths = ["/wp-admin", "/wp-admin/*", "/wp-login.php"]
  iap_public_paths    = ["/wp-admin/admin-ajax.php"]
}
