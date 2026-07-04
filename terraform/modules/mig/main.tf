# Instance template
resource "google_compute_instance_template" "this" {
  name_prefix  = var.template_name_prefix
  machine_type = var.machine_type
  region       = var.region

  lifecycle {
    create_before_destroy = true
  }

  disk {
    source_image = var.source_image
    auto_delete  = true
    boot         = true
    disk_size_gb = var.disk_size_gb
    disk_type    = var.disk_type
  }

  network_interface {
    network    = var.network
    subnetwork = var.subnetwork
  }

  metadata = {
    "startup-script" = var.startup_script
    "enable-oslogin" = "true"
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  tags = var.tags

}

# Regional MIG
resource "google_compute_region_instance_group_manager" "this" {
  name               = var.mig_name
  base_instance_name = var.base_instance_name
  region             = var.region

  # Distribute instances across these zones
  distribution_policy_zones = var.distribution_policy_zones

  # Even distribution across zones
  distribution_policy_target_shape = var.distribution_policy_target_shape

  version {
    instance_template = google_compute_instance_template.this.self_link
  }

  named_port {
    name = var.port_name
    port = var.port
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.http.self_link
    initial_delay_sec = var.initial_delay_sec
  }

  update_policy {
    type                           = var.update_policy_type
    minimal_action                 = var.update_policy_minimal_action
    most_disruptive_allowed_action = var.most_disruptive_allowed_action
    max_surge_fixed                = var.max_surge_fixed
    max_unavailable_fixed          = var.max_unavailable_fixed
  }
}

# Health Check
resource "google_compute_health_check" "http" {
  name                = var.health_check_name
  check_interval_sec  = var.check_interval_sec
  timeout_sec         = var.timeout_sec
  healthy_threshold   = var.healthy_threshold
  unhealthy_threshold = var.unhealthy_threshold

  http_health_check {
    port         = var.health_check_port
    request_path = var.request_path
  }
}

# Autoscaler for the regional MIG
resource "google_compute_region_autoscaler" "this" {
  name   = var.autoscaler_name
  region = var.region
  target = google_compute_region_instance_group_manager.this.id

  autoscaling_policy {
    min_replicas    = var.min_replicas
    max_replicas    = var.max_replicas
    cooldown_period = var.cooldown_period

    load_balancing_utilization {
      target = var.lb_utilization_target
    }

    # Scale-in controls to prevent aggressive scale-down
    scale_in_control {
      max_scaled_in_replicas {
        fixed = var.max_scaled_in_replicas
      }
      time_window_sec = var.time_window_sec
    }
  }
}


