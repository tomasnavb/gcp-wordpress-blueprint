locals {
  ip_protocol = "TCP"

  # Every resource is named <name_prefix>-<component>-<environment>, following the naming convention.
  names = {
    ip            = "${var.name_prefix}-ip-${var.environment}"
    ssl_policy    = "${var.name_prefix}-ssl-policy-${var.environment}"
    https_rule    = "${var.name_prefix}-https-fr-${var.environment}"
    http_rule     = "${var.name_prefix}-http-fr-${var.environment}"
    https_proxy   = "${var.name_prefix}-https-proxy-${var.environment}"
    http_proxy    = "${var.name_prefix}-http-proxy-${var.environment}"
    url_map       = "${var.name_prefix}-url-map-${var.environment}"
    redirect      = "${var.name_prefix}-redirect-${var.environment}"
    backend       = "${var.name_prefix}-backend-${var.environment}"
    health_check  = "${var.name_prefix}-hc-${var.environment}"
    firewall_rule = "${var.name_prefix}-allow-google-fe-${var.environment}"
  }

  # Same name in both modes: the address this module creates, or the one reserved beforehand
  # that it looks up. Either way the forwarding rules use local.ip_address.
  ip_address_name = local.names.ip
  ip_address = (
    var.use_reserved_ip
    ? data.google_compute_global_address.reserved[0].address
    : google_compute_global_address.external_ip[0].address
  )

  # The certificate name changes with the domain list. Together with create_before_destroy,
  # a domain change creates the new certificate before the old one is removed from the proxy.
  # The hash goes last, so the environment cannot be the last part of this name.
  certificate_name = "${var.name_prefix}-cert-${var.environment}-${substr(md5(join(",", var.domain_names)), 0, 8)}"

  # Google front end ranges. With a global external Application Load Balancer both the
  # health check probes and the proxied client traffic reach the backends from these ranges.
  google_frontend_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
}

# ==========================================
# 1. FRONTEND INFRASTRUCTURE & ENTRY POINTS
# ==========================================

# Global external IP address used as the single entry point for all incoming traffic.
# Two modes, selected by var.use_reserved_ip:
#
#   true  - the address was reserved outside Terraform (configs/setup.sh) and is only looked up
#           here by name. It survives terraform destroy, so the DNS record keeps pointing to it.
#   false - the address is created here and destroyed with the rest of the load balancer.
#           Every new deploy gets a different IP and the DNS record has to be updated.
data "google_compute_global_address" "reserved" {
  count = var.use_reserved_ip ? 1 : 0
  name  = local.ip_address_name
}

resource "google_compute_global_address" "external_ip" {
  count = var.use_reserved_ip ? 0 : 1
  name  = local.ip_address_name
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
  name            = local.names.ssl_policy
  profile         = var.ssl_policy_profile
  min_tls_version = var.min_tls_version
}

# Global forwarding rule that intercepts HTTPS traffic on port 443 and routes it to the HTTPS proxy
resource "google_compute_global_forwarding_rule" "https" {
  name                  = local.names.https_rule
  ip_protocol           = local.ip_protocol
  load_balancing_scheme = var.load_balancing_scheme
  port_range            = "443"
  ip_address            = local.ip_address
  target                = google_compute_target_https_proxy.https.id
}

# Global forwarding rule that intercepts plain HTTP traffic on port 80, on the same IP,
# and routes it to the HTTP proxy, whose only job is to redirect to HTTPS
resource "google_compute_global_forwarding_rule" "http" {
  name                  = local.names.http_rule
  ip_protocol           = local.ip_protocol
  load_balancing_scheme = var.load_balancing_scheme
  port_range            = "80"
  ip_address            = local.ip_address
  target                = google_compute_target_http_proxy.http.id
}

# ==========================================
# 2. PROXIES & ROUTING COMPONENT WORKFLOWS
# ==========================================

# Target HTTPS proxy that terminates SSL connections and forwards requests to the production URL map
resource "google_compute_target_https_proxy" "https" {
  name             = local.names.https_proxy
  url_map          = google_compute_url_map.external_lb_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.https.id]
  ssl_policy       = google_compute_ssl_policy.https.id
}

# Target HTTP proxy used to capture plain HTTP traffic and bind it to the redirect URL map
resource "google_compute_target_http_proxy" "http" {
  name    = local.names.http_proxy
  url_map = google_compute_url_map.http_redirect.id
}

# URL map that handles incoming traffic and matches hostname/path rules to the production backend service
resource "google_compute_url_map" "external_lb_url_map" {
  name            = local.names.url_map
  default_service = google_compute_backend_service.mig.self_link
}

# URL map dedicated to issuing a permanent 301 redirect for all plain HTTP traffic towards HTTPS
resource "google_compute_url_map" "http_redirect" {
  name = local.names.redirect

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
  name                  = local.names.backend
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
  name = local.names.health_check

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
  name    = local.names.firewall_rule
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
