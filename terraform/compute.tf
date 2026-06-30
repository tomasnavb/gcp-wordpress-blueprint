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

module "wordpress_regional_mig" {
  source = "./modules/mig"

  region = var.subnet_prod_region

  # Instance template
  template_name_prefix  = var.instance_template_name_prefix
  machine_type          = var.machine_type
  source_image          = local.source_image
  disk_size_gb          = local.disk_size_gb
  disk_type             = local.disk_type
  network               = module.vpc_prod.vpc_self_link
  subnetwork            = var.subnet_prod_name
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

module "external_lb" {
  source                = "./modules/external_lb"
  region                = var.subnet_prod_region
  dedicated_subnet_cidr = var.lb_dedicated_ip_cidr
  balancing_mode        = "RATE"
  mig_instance_group    = module.wordpress_regional_mig.self_link
  vpc_id                = module.vpc_prod.vpc_id
}
