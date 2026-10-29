# Latest image of the golden image family, resolved to a concrete image on every plan.
# The family URL alone never changes, so Terraform would not notice a new Packer build.
# With the concrete image, a new build shows up as an instance template replacement and
# the MIG rolls it out. The plan fails here if no image has been built yet.
data "google_compute_image" "wordpress_golden" {
  family  = local.image_family
  project = var.project_id
}

module "wordpress_regional_mig" {
  source = "./modules/mig"

  # Instances must not boot before what their startup script needs is ready: the secrets with
  # their values (the database host only exists once Cloud SQL is created), the bindings that
  # let them read those secrets, already propagated, the database and user WordPress connects to,
  # and the uploads folder of the uploads bucket, which they mount.
  # Without this the first instances boot minutes too early and fail to configure themselves.
  depends_on = [
    google_storage_bucket_object.uploads_folder,
    google_secret_manager_secret_version.wordpress_secrets,
    google_secret_manager_secret_version.db_password,
    time_sleep.web_vm_iam_propagation,
    google_sql_database.wordpress_db,
    google_sql_user.wordpress_app_user,
  ]

  region = var.project_region

  # Instance template
  template_name_prefix = local.web_template_name_prefix
  machine_type         = var.machine_type
  source_image         = data.google_compute_image.wordpress_golden.self_link
  disk_size_gb         = local.disk_size_gb
  disk_type            = local.disk_type
  network              = module.vpc.network_self_link
  subnetwork           = module.vpc.subnets["${var.project_region}/${local.web_subnet_name}"].id
  startup_script       = file("${path.root}/scripts/startup-prod.sh")
  # Read by startup-prod.sh, so the names it uses are always the ones Terraform created:
  # - uploads-bucket and uploads-folder: what to mount. The reference to the bucket resource also
  #   makes the instances wait until it exists.
  # - secret-db-*: the names of the database secrets.
  # - site-url: the address of the site, the first of var.domain_names. WordPress builds its links and
  #   redirects, the password reset link among them, from WP_HOME and WP_SITEURL, which the script sets
  #   to this value: never from the Host header of the request, which the client writes.
  # db-password-version is not read by anything: it is here so that rotating the password changes
  # the instance template, which makes the MIG replace the instances. They only read the password
  # at boot, so without a replacement they would keep the old one and lose the database.
  extra_metadata = {
    "uploads-bucket"      = google_storage_bucket.uploads.name
    "uploads-folder"      = local.uploads_folder
    "secret-db-name"      = local.db_secret_names.name
    "secret-db-user"      = local.db_secret_names.user
    "secret-db-password"  = local.db_secret_names.password
    "secret-db-host"      = local.db_secret_names.host
    "site-url"            = "https://${var.domain_names[0]}"
    "db-password-version" = tostring(var.db_password_version)
  }
  service_account_email = google_service_account.web_vm.email
  tags                  = [local.backend_network_tag, local.web_ssh_network_tag]

  # MIG
  mig_name                         = local.web_mig_name
  base_instance_name               = local.web_instance_base_name
  distribution_policy_zones        = var.distribution_policy_zones
  distribution_policy_target_shape = var.distribution_policy_target_shape
  port_name                        = var.port_name
  port                             = var.port
  initial_delay_sec                = var.initial_delay_sec
  update_policy_type               = var.update_policy_type
  update_policy_minimal_action     = var.update_policy_minimal_action
  most_disruptive_allowed_action   = var.most_disruptive_allowed_action
  max_surge_fixed                  = var.max_surge_fixed
  max_unavailable_fixed            = var.max_unavailable_fixed

  # Health check
  health_check_name   = local.web_health_check_name
  check_interval_sec  = var.check_interval_sec
  timeout_sec         = var.timeout_sec
  healthy_threshold   = var.healthy_threshold
  unhealthy_threshold = var.unhealthy_threshold
  health_check_port   = var.health_check_port
  request_path        = var.request_path

  # Autoscaler
  autoscaler_name        = local.web_autoscaler_name
  min_replicas           = var.min_replicas
  max_replicas           = var.max_replicas
  cooldown_period        = var.cooldown_period
  lb_utilization_target  = var.lb_utilization_target
  time_window_sec        = var.time_window_sec
  max_scaled_in_replicas = var.max_scaled_in_replicas
}

module "global_external_lb" {
  source = "./modules/global_external_lb"

  # Resource names: <name_prefix>-<component>-<environment>, e.g. wp-blueprint-lb-ip-prod.
  # With use_reserved_ip the IP is looked up by that name: configs/setup.sh reserves it with the same one.
  name_prefix     = local.lb_name_prefix
  environment     = var.environment
  use_reserved_ip = var.lb_use_reserved_ip

  # Firewall rule that lets the Google front ends reach the backends (health checks and proxied traffic).
  # Only the backend tag: the instances also carry the IAP SSH tag, which is unrelated to the LB.
  project_id          = var.project_id
  network_self_link   = module.vpc.network_self_link
  backend_target_tags = [local.backend_network_tag]

  # Backend: the MIG and the named port it serves on
  mig_instance_group = module.wordpress_regional_mig.instance_group
  backend_port_name  = var.port_name
  backend_port       = var.port

  # HTTPS: Google-managed certificate and minimum TLS version
  domain_names       = var.domain_names
  ssl_policy_profile = "MODERN"
  min_tls_version    = "TLS_1_2"

  # Uploads served from the bucket (backend bucket with Cloud CDN, Private Bucket Access)
  project_number      = data.google_project.this.number
  uploads_bucket_name = google_storage_bucket.uploads.name
  uploads_path        = "/${local.uploads_folder}/*"

  # Cloud CDN. A new upload gets a new file name, so it is never served stale. The TTL bounds how long
  # a deleted or overwritten upload keeps being served: an hour, in Cloud CDN and in browsers. For an
  # urgent removal, invalidate the path in Cloud CDN (README, Operations); browsers keep their copy
  # up to the client TTL. Static responses from the instances follow their own headers, an hour by
  # default.
  uploads_cdn_default_ttl = 3600
  uploads_cdn_client_ttl  = 3600
  backend_cdn_default_ttl = 3600
  backend_cdn_max_ttl     = 86400
  backend_cdn_client_ttl  = 3600

  # Cloud Armor. OWASP Core Rule Set 4.22, the version Google recommends. Sensitivity 1 gives the fewest
  # false positives. Rule sets for the stack this site runs (PHP on Apache) and generic attacks; java is left out.
  waf_rule_sets = [
    "sqli-v422-stable",
    "xss-v422-stable",
    "lfi-v422-stable",
    "rfi-v422-stable",
    "rce-v422-stable",
    "php-v422-stable",
    "scannerdetection-v422-stable",
    "protocolattack-v422-stable",
    "methodenforcement-v422-stable",
    "sessionfixation-v422-stable",
    "generic-v422-stable",
  ]
  waf_sensitivity = 1
  waf_preview     = var.waf_preview
  # Login, per IP: 5 attempts per minute, a 429 over that. An IP that keeps pushing past the limit, over
  # 50 attempts in 10 minutes (the most the limit lets through in that window), is banned for 30 minutes.
  # Starting values from Cloud Armor's login example, common WordPress guidance and OWASP lockout
  # durations; tune them with the RATE_LIMIT_THRESHOLD_EXCEED and BAN_THRESHOLD_EXCEED entries of the
  # load balancer logs.
  login_rate_limit_count        = 5
  login_rate_limit_interval_sec = 60
  login_ban_threshold_count     = 50
  login_ban_interval_sec        = 600
  login_ban_duration_sec        = 1800

  # IAP for the admin area. Empty: no IAP backend (set in the next step of the refactor block).
  iap_protected_paths = []
  iap_public_paths    = []
  iap_members         = []

  # LB configuration
  http_health_check_port    = var.health_check_port
  health_check_request_path = var.request_path
  backend_service_protocol  = "HTTP"
  load_balancing_scheme     = "EXTERNAL_MANAGED"
  balancing_mode            = "RATE"
  max_rate_per_instance     = 100
  capacity_scaler           = 1.0
}

# Project number, for the name of the Google-managed service account the load balancer reads the
# uploads bucket with. Read from the API, never written in the code.
data "google_project" "this" {
  project_id = var.project_id
}
