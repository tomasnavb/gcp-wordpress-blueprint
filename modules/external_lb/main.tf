# External Load Balancer Configuration

// Subnet for external managed HTTP(S) LB proxies
resource "google_compute_subnetwork" "external_lb_subnet" {
  name          = "${var.subnet_name}${local.lb_suffix}"
  network       = var.vpc_id
  region        = var.region
  ip_cidr_range = var.subnet_cidr
  purpose       = var.subnet_purpose
  role          = var.subnet_role
}

// External IP for external managed LB
resource "google_compute_address" "external_ip" {
  name   = "${var.ip_address_name}${local.lb_suffix}"
  region = var.ip_address_region
}

resource "google_compute_forwarding_rule" "external_lb" {
  name        = local.fr_full_name
  network     = google_compute_subnetwork.external_lb_subnet.self_link
  target      = google_compute_region_target_http_proxy.external_lb_http_proxy.self_link
  ip_address  = google_compute_address.external_ip.self_link
  region      = var.region
  ip_protocol = local.fr_ip_protocol
  port_range  = var.listener_port


}

resource "google_compute_region_target_http_proxy" "external_lb_http_proxy" {
  name   = var.lb_name
  region = var.region

  url_map = google_compute_region_url_map.external_lb_url_map.id

  depends_on = [
    google_compute_subnetwork.external_lb_proxy
  ]
}

resource "google_compute_region_url_map" "external_lb_url_map" {
  name   = "${var.url_map_name}${local.lb_suffix}"
  region = var.region

  default_service = google_compute_region_backend_service.umig_backend.self_link

  depends_on = [
    google_compute_subnetwork.external_lb_subnet
  ]
}

resource "google_compute_region_health_check" "backend_health_check" {
  name   = "${var.health_check_name}${local.lb_suffix}"
  region = var.region
  http_health_check {
    port = var.http_health_check_port
  }
}

resource "google_compute_instance_group" "umig" {
  name      = var.backend_group_name
  zone      = "${var.region}-a"
  instances = var.umig_instances
}


resource "google_compute_region_backend_service" "umig_backend" {
  name                  = var.backend_service_name
  region                = var.region
  protocol              = var.backend_service_protocol
  load_balancing_scheme = var.load_balancing_scheme
  health_checks         = [google_compute_region_health_check.backend_health_check.self_link]
  backend {
    group = google_compute_instance_group.umig.self_link
  }

}
