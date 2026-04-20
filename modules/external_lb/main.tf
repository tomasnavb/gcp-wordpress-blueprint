# External Load Balancer Configuration

// Subnet for external managed HTTP(S) LB proxies
resource "google_compute_subnetwork" "external_lb_proxy" {
  name          = var.external_lb_proxy_subnet_name
  network       = var.vpc_id
  region        = var.region
  ip_cidr_range = var.external_lb_proxy_subnet_cidr
  purpose       = var.external_lb_proxy_subnet_purpose
  role          = var.external_lb_proxy_subnet_role
}

// External IP for external managed LB
resource "google_compute_address" "external_lb" {
  name   = var.external_lb_ip_address_name
  region = var.region
}

resource "google_compute_region_url_map" "external_lb_url_map" {
  name   = "gcp-lb-demo-external-lb-url-map"
  region = var.region

  default_service = google_compute_region_backend_service.umig_backend.self_link

  depends_on = [
    google_compute_subnetwork.external_lb_proxy
  ]
}

resource "google_compute_region_health_check" "umig" {
  name   = "gcp-lb-demo-health-check-umig"
  region = var.region
  http_health_check {
    port = 80
  }
}

resource "google_compute_region_backend_service" "umig_backend" {
  name                  = "gcp-lb-demo-backend-service"
  region                = var.region
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks         = [google_compute_region_health_check.umig.self_link]
  backend {
    group = google_compute_instance_group.umig.self_link
  }

}

resource "google_compute_instance_group" "umig" {
  name      = "umig-backend-group"
  zone      = "${var.region}-a"
  instances = var.umig_instances
}

resource "google_compute_region_target_http_proxy" "external_lb_http_proxy" {
  name   = "gcp-lb-demo-external-lb-http-proxy"
  region = var.region

  url_map = google_compute_region_url_map.external_lb_url_map.id

  depends_on = [
    google_compute_subnetwork.external_lb_proxy
  ]
}
