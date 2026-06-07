# Subnet for external managed HTTP(S) LB proxies
resource "google_compute_subnetwork" "external_lb_proxy" {
  # Subnet name includes "-external-lb" as fixed suffix for name convention purpose
  name          = "${var.subnet_name}${local.lb_suffix}"
  network       = var.vpc_id
  region        = var.region
  ip_cidr_range = var.dedicated_subnet_cidr
  purpose       = local.subnet_purpose
  # Active role by default
  role = var.subnet_role
}

# External IP address
resource "google_compute_address" "external_ip" {
  name   = "${var.ip_address_name}${local.lb_suffix}"
  region = var.region
}

resource "google_compute_forwarding_rule" "external_lb" {
  name                  = local.fr_full_name
  region                = var.region
  ip_protocol           = local.ip_protocol
  load_balancing_scheme = local.load_balancing_scheme

  # External listener port (default 80)
  port_range = var.listener_port
  network    = var.vpc_id

  ip_address = google_compute_address.external_ip.address
  target     = google_compute_region_target_http_proxy.external_lb_http_proxy.id

  depends_on = [
    google_compute_subnetwork.external_lb_proxy
  ]
}

resource "google_compute_region_url_map" "external_lb_url_map" {
  name   = "${var.url_map_name}${local.lb_suffix}"
  region = var.region

  default_service = google_compute_region_backend_service.mig.self_link

  depends_on = [
    google_compute_subnetwork.external_lb_proxy
  ]
}

resource "google_compute_region_target_http_proxy" "external_lb_http_proxy" {
  name   = var.lb_name
  region = var.region

  url_map = google_compute_region_url_map.external_lb_url_map.id

  depends_on = [
    google_compute_subnetwork.external_lb_proxy
  ]
}

resource "google_compute_region_health_check" "backend_health_check" {
  name   = "${var.health_check_name}${local.lb_suffix}"
  region = var.region

  http_health_check {
    port = var.http_health_check_port
  }
}

resource "google_compute_region_backend_service" "mig" {
  name                  = var.backend_service_name
  region                = var.region
  protocol              = var.backend_service_protocol
  load_balancing_scheme = var.load_balancing_scheme

  health_checks = [
    google_compute_region_health_check.backend_health_check.self_link
  ]

  backend {
    group           = var.mig_instance_group
    balancing_mode  = var.balancing_mode
    capacity_scaler = var.capacity_scaler
  }

}
