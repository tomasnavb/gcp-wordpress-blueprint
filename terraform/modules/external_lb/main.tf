locals {
  lb_suffix      = "-external-lb"
  subnet_purpose = "REGIONAL_MANAGED_PROXY"
  ip_protocol    = "TCP"
  fr_full_name   = "${var.lb_name}-forwarding-rule"
}

# Proxy-only subnet required for regional external Application Load Balancer
resource "google_compute_subnetwork" "external_lb_proxy" {
  name          = "${var.subnet_name}${local.lb_suffix}"
  network       = var.vpc_id
  region        = var.region
  ip_cidr_range = var.dedicated_subnet_cidr
  purpose       = local.subnet_purpose
  role          = var.subnet_role
}

# Reserved external IP address for the forwarding rule
resource "google_compute_address" "external_ip" {
  name   = "${var.ip_address_name}${local.lb_suffix}"
  region = var.region
}

# Forwarding rule — entry point for external traffic
resource "google_compute_forwarding_rule" "external_lb" {
  name                  = local.fr_full_name
  region                = var.region
  ip_protocol           = local.ip_protocol
  load_balancing_scheme = var.load_balancing_scheme
  port_range            = var.listener_port
  network               = var.vpc_id
  ip_address            = google_compute_address.external_ip.address
  target                = google_compute_region_target_http_proxy.external_lb_http_proxy.id

  depends_on = [google_compute_subnetwork.external_lb_proxy]
}

# URL map — routes requests to the backend service
resource "google_compute_region_url_map" "external_lb_url_map" {
  name            = "${var.url_map_name}${local.lb_suffix}"
  region          = var.region
  default_service = google_compute_region_backend_service.mig.self_link

  depends_on = [google_compute_subnetwork.external_lb_proxy]
}

# HTTP proxy — connects the forwarding rule to the URL map
resource "google_compute_region_target_http_proxy" "external_lb_http_proxy" {
  name    = var.lb_name
  region  = var.region
  url_map = google_compute_region_url_map.external_lb_url_map.id

  depends_on = [google_compute_subnetwork.external_lb_proxy]
}

# Regional health check for the LB backend service (separate from the MIG auto-healing health check)
resource "google_compute_region_health_check" "backend_health_check" {
  name   = "${var.health_check_name}${local.lb_suffix}"
  region = var.region

  http_health_check {
    port         = var.http_health_check_port
    request_path = "/health.php"
  }
}

# Backend service — connects the URL map to the MIG
resource "google_compute_region_backend_service" "mig" {
  name                  = var.backend_service_name
  region                = var.region
  protocol              = var.backend_service_protocol
  load_balancing_scheme = var.load_balancing_scheme

  health_checks = [google_compute_region_health_check.backend_health_check.self_link]

  backend {
    group                 = var.mig_instance_group
    balancing_mode        = var.balancing_mode
    max_rate_per_instance = var.max_rate_per_instance
    capacity_scaler       = var.capacity_scaler
  }
}
