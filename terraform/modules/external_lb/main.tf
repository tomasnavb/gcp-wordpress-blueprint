locals {
  lb_suffix   = "-external-lb"
  ip_protocol = "TCP"

  # The certificate name changes with the domain list. Together with create_before_destroy,
  # a domain change creates the new certificate before the old one is removed from the proxy.
  certificate_name = "${var.lb_name}-cert-${substr(md5(join(",", var.domain_names)), 0, 8)}"

  # Google front end ranges. With a global external Application Load Balancer both the
  # health check probes and the proxied client traffic reach the backends from these ranges.
  google_frontend_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
}

# ==========================================
# 1. FRONTEND INFRASTRUCTURE & ENTRY POINTS
# ==========================================

# Reserved global external IP address used as the single entry point for all incoming traffic
resource "google_compute_global_address" "external_ip" {
  name = "${var.ip_address_name}${local.lb_suffix}"
}

# Google-managed SSL certificate that automatically handles domain validation and renewals.
# It is only issued once the DNS A record of each domain points to the load balancer IP.
resource "google_compute_managed_ssl_certificate" "https" {
  name = local.certificate_name

  managed {
    domains = var.domain_names
  }

  lifecycle {
    create_before_destroy = true
  }
}

# SSL policy that sets the minimum TLS version and cipher profile accepted from clients.
# Without one the proxy uses the default policy, which still accepts TLS 1.0.
resource "google_compute_ssl_policy" "https" {
  name            = "${var.lb_name}-ssl-policy"
  profile         = var.ssl_policy_profile
  min_tls_version = var.min_tls_version
}

# Global forwarding rule that intercepts HTTPS traffic on port 443 and routes it to the HTTPS proxy
resource "google_compute_global_forwarding_rule" "https" {
  name                  = "${var.lb_name}-https-forwarding-rule"
  ip_protocol           = local.ip_protocol
  load_balancing_scheme = var.load_balancing_scheme
  port_range            = "443"
  ip_address            = google_compute_global_address.external_ip.address
  target                = google_compute_target_https_proxy.https.id
}

# Global forwarding rule that intercepts plain HTTP traffic on port 80, on the same IP,
# and routes it to the HTTP proxy, whose only job is to redirect to HTTPS
resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.lb_name}-http-forwarding-rule"
  ip_protocol           = local.ip_protocol
  load_balancing_scheme = var.load_balancing_scheme
  port_range            = "80"
  ip_address            = google_compute_global_address.external_ip.address
  target                = google_compute_target_http_proxy.http.id
}

# ==========================================
# 2. PROXIES & ROUTING COMPONENT WORKFLOWS
# ==========================================

# Target HTTPS proxy that terminates SSL connections and forwards requests to the production URL map
resource "google_compute_target_https_proxy" "https" {
  name             = "${var.lb_name}-https-proxy"
  url_map          = google_compute_url_map.external_lb_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.https.id]
  ssl_policy       = google_compute_ssl_policy.https.id
}

# Target HTTP proxy used to capture plain HTTP traffic and bind it to the redirect URL map
resource "google_compute_target_http_proxy" "http" {
  name    = "${var.lb_name}-http-proxy"
  url_map = google_compute_url_map.http_redirect.id
}

# URL map that handles incoming traffic and matches hostname/path rules to the production backend service
resource "google_compute_url_map" "external_lb_url_map" {
  name            = "${var.url_map_name}${local.lb_suffix}"
  default_service = google_compute_backend_service.mig.self_link
}

# URL map dedicated to issuing a permanent 301 redirect for all plain HTTP traffic towards HTTPS
resource "google_compute_url_map" "http_redirect" {
  name = "${var.lb_name}-http-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

# ==========================================
# 3. BACKEND SERVICES & HEALTH MONITORING
# ==========================================

# Backend service that orchestrates target groups, scaling parameters, and load balancing configurations.
# port_name must match a named port of the instance group.
resource "google_compute_backend_service" "mig" {
  name                  = var.backend_service_name
  protocol              = var.backend_service_protocol
  port_name             = var.backend_port_name
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
    request_path = var.health_check_request_path
  }
}

# ==========================================
# 4. FIREWALL
# ==========================================

# Lets the Google front ends reach the backends. This single rule covers both the health check
# probes and the client traffic proxied by the load balancer, which arrive from the same ranges.
resource "google_compute_firewall" "allow_google_frontends" {
  name    = "${var.lb_name}-allow-google-frontends"
  project = var.project_id
  network = var.network_self_link

  direction     = "INGRESS"
  source_ranges = local.google_frontend_ranges
  target_tags   = var.backend_target_tags

  allow {
    protocol = "tcp"
    ports    = distinct([tostring(var.backend_port), tostring(var.http_health_check_port)])
  }
}
