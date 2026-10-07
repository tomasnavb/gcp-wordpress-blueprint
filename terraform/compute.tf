resource "google_compute_instance" "management" {
  name         = var.vm_mgmt_name
  machine_type = var.vm_mgmt_machine_type
  tags         = ["iap-ssh-access"]

  network_interface {
    network    = module.vpc_mgmt.vpc_self_link
    subnetwork = module.vpc_mgmt.subnet_id
    stack_type = "IPV4_ONLY"
  }

  boot_disk {
    initialize_params {
      image = local.source_image
      size  = local.disk_size_gb
      type  = local.disk_type
    }
  }

  metadata = {
    "startup-script" = file("${path.root}/scripts/startup-mgmt.sh")
  }

  service_account {
    email  = google_service_account.mgmt_vm.email
    scopes = ["cloud-platform"]
  }
}

# Latest image of the wordpress-golden family, resolved to a concrete image on every plan.
# The family URL alone never changes, so Terraform would not notice a new Packer build.
# With the concrete image, a new build shows up as an instance template replacement and
# the MIG rolls it out. The plan fails here if no image has been built yet.
data "google_compute_image" "wordpress_golden" {
  family  = "wordpress-golden"
  project = var.project_id
}

module "wordpress_regional_mig" {
  source = "./modules/mig"

  region = var.subnet_prod_region

  # Instance template
  template_name_prefix  = var.instance_template_name_prefix
  machine_type          = var.machine_type
  source_image          = data.google_compute_image.wordpress_golden.self_link
  disk_size_gb          = local.disk_size_gb
  disk_type             = local.disk_type
  network               = module.vpc_prod.vpc_self_link
  subnetwork            = module.vpc_prod.subnet_id
  startup_script        = file("${path.root}/scripts/startup-prod.sh")
  service_account_email = google_service_account.prod_vm.email
  tags                  = var.instance_template_tags

  # MIG
  mig_name                         = var.mig_name
  base_instance_name               = var.base_instance_name
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
  health_check_name   = var.health_check_name
  check_interval_sec  = var.check_interval_sec
  timeout_sec         = var.timeout_sec
  healthy_threshold   = var.healthy_threshold
  unhealthy_threshold = var.unhealthy_threshold
  health_check_port   = var.health_check_port
  request_path        = var.request_path

  # Autoscaler
  autoscaler_name        = var.autoscaler_name
  min_replicas           = var.min_replicas
  max_replicas           = var.max_replicas
  cooldown_period        = var.cooldown_period
  lb_utilization_target  = var.lb_utilization_target
  time_window_sec        = var.time_window_sec
  max_scaled_in_replicas = var.max_scaled_in_replicas
}

module "global_external_lb" {
  source = "./modules/global_external_lb"

  # Firewall rule that lets the Google front ends reach the backends (health checks and proxied traffic).
  # Only the backend tag: the template also carries "iap-ssh-access", which is unrelated to the LB.
  project_id          = var.project_id
  network_self_link   = module.vpc_prod.vpc_self_link
  backend_target_tags = ["backend-service"]

  # Backend: the MIG and the named port it serves on
  mig_instance_group = module.wordpress_regional_mig.instance_group
  backend_port_name  = var.port_name
  backend_port       = var.port

  # Resource names (module appends "-global-external-lb" suffix to IP, url_map, health_check;
  # every other resource is named after lb_name)
  ip_address_name      = "wordpress-prod-lb-ip"
  use_reserved_ip      = var.lb_use_reserved_ip
  lb_name              = "wordpress-prod-lb"
  url_map_name         = "wordpress-prod-lb-url-map"
  health_check_name    = "wordpress-prod-lb-hc"
  backend_service_name = "wordpress-prod-lb-backend-service"

  # HTTPS: Google-managed certificate and minimum TLS version
  domain_names       = var.domain_names
  ssl_policy_profile = "MODERN"
  min_tls_version    = "TLS_1_2"

  # LB configuration
  http_health_check_port    = var.health_check_port
  health_check_request_path = var.request_path
  backend_service_protocol  = "HTTP"
  load_balancing_scheme     = "EXTERNAL_MANAGED"
  balancing_mode            = "RATE"
  max_rate_per_instance     = 100
  capacity_scaler           = 1.0
}
