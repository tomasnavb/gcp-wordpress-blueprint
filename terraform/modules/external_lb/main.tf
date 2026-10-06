locals {
  lb_suffix    = "-external-lb"
  ip_protocol  = "TCP"
  fr_full_name = "${var.lb_name}-forwarding-rule"
}

# ==========================================
# 1. FRONTEND INFRASTRUCTURE & ENTRY POINTS
# ==========================================

# Reserved global external IP address used as the single entry point for all incoming traffic
resource "google_compute_global_address" "external_ip" {
  name = "${var.ip_address_name}${local.lb_suffix}"
}

# Google-managed SSL certificate that automatically handles domain validation and renewals
resource "google_compute_managed_ssl_certificate" "https" {
  name = "web-ssl-cert"

  managed {
    domains = var.domain_names
  }
}

# Global forwarding rule that intercepts HTTPS traffic on port 443 and routes it to the target proxy
resource "google_compute_global_forwarding_rule" "external_lb" {
  name                  = local.fr_full_name
  ip_protocol           = local.ip_protocol
  load_balancing_scheme = var.load_balancing_scheme
  port_range            = "443"
  ip_address            = google_compute_global_address.external_ip.address
  target                = google_compute_target_https_proxy.web.id
}

# ==========================================
# 2. PROXIES & ROUTING COMPONENT WORKFLOWS
# ==========================================

# Target HTTPS proxy that terminates SSL connections and forwards requests to the production URL map
resource "google_compute_target_https_proxy" "web" {
  name             = "web-https-proxy"
  url_map          = google_compute_url_map.external_lb_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.https.id]
}

# Target HTTP proxy used to capture plain HTTP traffic and bind it to the redirect URL map
resource "google_compute_target_http_proxy" "external_lb_http_proxy" {
  name    = var.lb_name
  url_map = google_compute_url_map.http_redirect.id
}

# URL map that handles incoming traffic and matches hostname/path rules to the production backend service
resource "google_compute_url_map" "external_lb_url_map" {
  name            = "${var.url_map_name}${local.lb_suffix}"
  default_service = google_compute_backend_service.mig.self_link
}

# URL map dedicated to issuing a permanent 301 redirect for all plain HTTP traffic towards HTTPS
resource "google_compute_url_map" "http_redirect" {
  name = "http-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

# ==========================================
# 3. BACKEND SERVICES & HEALTH MONITORING
# ==========================================

# Backend service that orchestrates target groups, scaling parameters, and load balancing configurations
resource "google_compute_backend_service" "mig" {
  name                  = var.backend_service_name
  protocol              = var.backend_service_protocol
  load_balancing_scheme = var.load_balancing_scheme

  health_checks = [google_compute_health_check.backend_health_check.self_link]

  backend {
    group                 = var.mig_instance_group
    balancing_mode        = var.balancing_mode
    max_rate_per_instance = var.max_rate_per_instance
    capacity_scaler       = var.capacity_scaler
  }
}

# Global health check designed to monitor individual instance readiness by probing the health status path
resource "google_compute_health_check" "backend_health_check" {
  name = "${var.health_check_name}${local.lb_suffix}"

  http_health_check {
    port         = var.http_health_check_port
    request_path = "/health.php"
  }
}

resource "google_compute_firewall" "allow_lb_health_checks" {
  name    = "allow-lb-health-checks"
  project = var.project_id
  network = var.network_self_link

  direction     = "INGRESS"
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = var.target_tags

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

