locals {
  ip_protocol = "TCP"

  # Every resource is named <name_prefix>-<component>-<environment>, following the naming convention.
  names = {
    ip              = "${var.name_prefix}-ip-${var.environment}"
    ssl_policy      = "${var.name_prefix}-ssl-policy-${var.environment}"
    https_rule      = "${var.name_prefix}-https-fr-${var.environment}"
    http_rule       = "${var.name_prefix}-http-fr-${var.environment}"
    https_proxy     = "${var.name_prefix}-https-proxy-${var.environment}"
    http_proxy      = "${var.name_prefix}-http-proxy-${var.environment}"
    url_map         = "${var.name_prefix}-url-map-${var.environment}"
    redirect        = "${var.name_prefix}-redirect-${var.environment}"
    backend         = "${var.name_prefix}-backend-${var.environment}"
    backend_iap     = "${var.name_prefix}-backend-iap-${var.environment}"
    health_check    = "${var.name_prefix}-hc-${var.environment}"
    firewall_rule   = "${var.name_prefix}-allow-google-fe-${var.environment}"
    uploads_backend = "${var.name_prefix}-uploads-backend-${var.environment}"
    security_policy = "${var.name_prefix}-armor-${var.environment}"
    iap_policy      = "${var.name_prefix}-armor-iap-${var.environment}"
  }

  # IAP is optional: with no protected paths there is no second backend service, no second security
  # policy and no extra path rules, and the load balancer works with a single backend service.
  iap_enabled = length(var.iap_protected_paths) > 0

  # Service account the load balancer and Cloud CDN read private buckets with (Private Bucket Access).
  # Google creates it once the project has its first backend bucket.
  lb_bucket_reader = "serviceAccount:service-${var.project_number}@https-lb.iam.gserviceaccount.com"

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

  # Regular expression for the Host header of the site's domains, used by Cloud Armor. A dot is
  # written "[.]" so it only matches a dot. The port is optional: a client may send it in the
  # header (www.example.com:443).
  allowed_hosts_regex = "^(${join("|", [for domain in var.domain_names : replace(domain, ".", "[.]")])})(:[0-9]+)?$"

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

# URL map of the HTTPS proxy. Uploads go to the bucket, everything else to WordPress on the MIG.
# No URL rewrite: the objects are stored under the same path WordPress serves them from, so a request
# for /wp-content/uploads/2026/10/photo.jpg reads the object wp-content/uploads/2026/10/photo.jpg.
#
# Only the site's own domains reach the path matcher. The client writes the Host header, so it can be
# anything: the load balancer IP, Google's reverse DNS name for it, or someone else's domain. Bots
# that sweep cloud IP ranges send those and find whatever answers (devlog-2026-10-26-verification.md,
# E4). A request with any other host goes to the URL map default.
#
# The default must not serve WordPress, but the URL map has no "deny" action: its default can only be
# a backend service, a backend bucket or a redirect. A redirect to the site would hand its domain to
# whoever sent the request, and a bucket default would be one more thing reachable from anywhere. So
# the default is the backend service, and its Cloud Armor policy answers 403 to any host that is not
# one of var.domain_names (rule "Block unknown hosts"). Do not remove that rule: without it, the
# default serves WordPress to every host again. It also keeps unknown hosts off the uploads bucket,
# whose path rule only exists in the path matcher of the site's domains.
resource "google_compute_url_map" "external_lb_url_map" {
  name            = local.names.url_map
  default_service = google_compute_backend_service.mig.self_link

  host_rule {
    hosts        = var.domain_names
    path_matcher = "wordpress"
  }

  path_matcher {
    name            = "wordpress"
    default_service = google_compute_backend_service.mig.self_link

    path_rule {
      paths   = [var.uploads_path]
      service = google_compute_backend_bucket.uploads.self_link
    }

    # Protected paths go to the backend behind IAP. Path rules are matched by specificity, not by
    # order: an exact path first, then the longest /* prefix, then the default of the path matcher.
    dynamic "path_rule" {
      for_each = local.iap_enabled ? [1] : []
      content {
        paths   = var.iap_protected_paths
        service = google_compute_backend_service.mig_iap[0].self_link
      }
    }

    # Paths under a protected prefix that the public site needs, such as /wp-admin/admin-ajax.php,
    # stay on the public backend. They are exact paths, so they win over the protected prefix.
    dynamic "path_rule" {
      for_each = local.iap_enabled && length(var.iap_public_paths) > 0 ? [1] : []
      content {
        paths   = var.iap_public_paths
        service = google_compute_backend_service.mig.self_link
      }
    }
  }
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

  # Cloud Armor runs on every request that reaches the instances (a cache hit never does).
  security_policy = google_compute_security_policy.wordpress.id

  # Request logs of the load balancer. Cloud Armor records its decisions in them: the WAF matches of
  # rules in preview, and the rate limit and ban outcomes of the login rule. Without them neither can be
  # reviewed or tuned. Every request is logged: the site has little traffic, so the cost is small.
  log_config {
    enable      = true
    sample_rate = 1.0
  }

  # Cloud CDN for what WordPress serves from the image: theme and plugin CSS, JavaScript, fonts and images.
  # CACHE_ALL_STATIC caches static content types, and never a response with Set-Cookie or
  # Cache-Control: private or no-store, nor HTML without caching headers. That keeps pages of logged-in
  # users and the admin area out of the cache. FORCE_CACHE_ALL is ruled out here: it ignores those
  # headers and could serve one user's page to another.
  enable_cdn = true
  cdn_policy {
    cache_mode  = "CACHE_ALL_STATIC"
    default_ttl = var.backend_cdn_default_ttl
    max_ttl     = var.backend_cdn_max_ttl
    client_ttl  = var.backend_cdn_client_ttl

    # Cache key: protocol, host and the full URL with its query string, as Cloud CDN does by default.
    # The provider requires the block to be explicit. The query string matters: WordPress versions
    # theme and plugin assets with ?ver=, so a new version gets a new cache entry instead of the old one.
    cache_key_policy {
      include_protocol     = true
      include_host         = true
      include_query_string = true
    }
  }

  backend {
    group                 = var.mig_instance_group
    balancing_mode        = var.balancing_mode
    max_rate_per_instance = var.max_rate_per_instance
    capacity_scaler       = var.capacity_scaler
  }
}

# Second backend service on the same instance group, behind IAP, for var.iap_protected_paths. Only
# the principals in var.iap_members reach it, after signing in with Google. Same instances and health
# check as the public backend: what changes is who can reach these paths, not what serves them.
#
# No Cloud CDN: IAP and Cloud CDN cannot be enabled on the same backend service, and admin pages must
# never be cached anyway. No oauth2_client_id: IAP uses the Google-managed OAuth client, which only
# admits users of the project's organization.
#
# On a global external Application Load Balancer, Cloud Armor is evaluated before IAP. This backend
# has its own security policy (section 4), because the public one blocks the protected paths.
resource "google_compute_backend_service" "mig_iap" {
  count = local.iap_enabled ? 1 : 0

  name                  = local.names.backend_iap
  protocol              = var.backend_service_protocol
  port_name             = var.backend_port_name
  load_balancing_scheme = var.load_balancing_scheme

  health_checks   = [google_compute_health_check.backend_health_check.self_link]
  security_policy = google_compute_security_policy.iap[0].id
  enable_cdn      = false

  iap {
    enabled = true
  }

  # Request logs: the Cloud Armor decisions of this backend, as on the public one.
  log_config {
    enable      = true
    sample_rate = 1.0
  }

  backend {
    group                 = var.mig_instance_group
    balancing_mode        = var.balancing_mode
    max_rate_per_instance = var.max_rate_per_instance
    capacity_scaler       = var.capacity_scaler
  }
}

# Who can reach the paths behind IAP.
resource "google_iap_web_backend_service_iam_member" "accessors" {
  for_each = local.iap_enabled ? toset(var.iap_members) : toset([])

  project             = var.project_id
  web_backend_service = google_compute_backend_service.mig_iap[0].name
  role                = "roles/iap.httpsResourceAccessor"
  member              = each.value
}

# Global health check designed to monitor individual instance readiness by probing the health status path
resource "google_compute_health_check" "backend_health_check" {
  name = local.names.health_check

  http_health_check {
    port         = var.http_health_check_port
    request_path = var.health_check_request_path
  }
}

# Backend bucket: WordPress uploads, served straight from Cloud Storage through Cloud CDN, without going
# through the instances. The bucket stays private (Private Bucket Access, below).
#
# FORCE_CACHE_ALL is required to cache a private bucket (Cloud CDN documentation, private bucket
# access). It is safe here: a bucket returns the same object to everyone who requests a URL, with no
# per-user responses. The pages of logged-in users are served by the backend service above, which
# keeps CACHE_ALL_STATIC. With FORCE_CACHE_ALL the TTL applied is default_ttl.
resource "google_compute_backend_bucket" "uploads" {
  name        = local.names.uploads_backend
  bucket_name = var.uploads_bucket_name
  enable_cdn  = true

  cdn_policy {
    cache_mode  = "FORCE_CACHE_ALL"
    default_ttl = var.uploads_cdn_default_ttl
    client_ttl  = var.uploads_cdn_client_ttl
  }
}

# Private Bucket Access: the load balancer reads the uploads bucket with a Google-managed service
# account, so the bucket needs no public access and public access prevention stays enforced. Objects
# can only be read through the load balancer, behind Cloud CDN. Read-only.
# depends_on: the service account only exists once the project has a backend bucket.
resource "google_storage_bucket_iam_member" "lb_uploads_reader" {
  bucket = var.uploads_bucket_name
  role   = "roles/storage.objectViewer"
  member = local.lb_bucket_reader

  depends_on = [google_compute_backend_bucket.uploads]
}

# ==========================================
# 4. CLOUD ARMOR
# ==========================================

# Two security policies: one for the public backend service, and one for the backend behind IAP when
# it exists. On a global external Application Load Balancer, Cloud Armor runs before IAP, and a rule
# cannot tell which backend a request goes to. So the protected paths can only be blocked on the
# public backend with a policy of its own. Rules are evaluated by priority, lowest number first; the
# first match decides.
#
# Each rule is defined once, in the locals below, and each policy takes the ones it needs:
#
#   Rule                                Public policy               IAP policy
#   Block unknown hosts                 yes                         yes
#   Block xmlrpc.php                    yes                         no (never routed there)
#   Block protected paths outside IAP   only when IAP is enabled    no
#   Login rate limit and ban            only when IAP is disabled   yes
#   Preconfigured WAF rules             yes                         yes
#
# Path expressions are regular expressions: anchored at the start, "/+" also catches repeated
# slashes, and "[.]" is a literal dot without backslash escaping. No end anchor: PHP also runs
# /xmlrpc.php/anything.
locals {
  # Any Host header that is not one of the site's domains: requests the URL map sent to its default
  # (see the URL map above). Without this rule they would be served by WordPress. A request without a
  # Host header is blocked too. Health checks do not go through Cloud Armor, so they are not affected.
  rule_unknown_hosts = {
    priority    = 50
    description = "Block unknown hosts"
    expression  = "!has(request.headers['host']) || !request.headers['host'].lower().matches('${local.allowed_hosts_regex}')"
    preview     = false
  }

  # xmlrpc.php: a classic brute force target, not used by this site. Blocked, not rate limited:
  # system.multicall tries hundreds of passwords in a single request.
  rule_xmlrpc = {
    priority    = 100
    description = "Block xmlrpc.php"
    expression  = "request.path.matches('^/+xmlrpc[.]php')"
    preview     = false
  }

  # The path rules of the URL map compare the path as it arrives, but Apache and PHP read it more
  # loosely: /wp-login.php/x runs wp-login.php, and //wp-admin/ or an encoded character can reach the
  # same files. Such a request matches no protected path rule, goes to the public backend and would
  # skip IAP. On the public backend, this rule blocks any path that contains a protected path, after
  # decoding and lowercasing it as Cloud Armor recommends, except the exact public paths:
  #   /wp-admin/*                 ->  /wp-admin(/|$)                    anywhere in the path
  #   /wp-login.php               ->  /wp-login[.]php                   anywhere in the path
  #   /wp-admin/admin-ajax.php    ->  ^/+wp-admin/+admin-ajax[.]php$    the whole path
  protected_paths_regex = join("|", [
    for path in var.iap_protected_paths :
    endswith(path, "/*")
    ? "${replace(lower(trimsuffix(path, "/*")), ".", "[.]")}(/|$)"
    : replace(lower(path), ".", "[.]")
  ])
  public_paths_regex = join("|", [
    for path in var.iap_public_paths : "^${replace(replace(lower(path), ".", "[.]"), "/", "/+")}$"
  ])
  rule_protected_paths = {
    priority    = 150
    description = "Block protected paths outside IAP"
    expression = (
      length(var.iap_public_paths) > 0
      ? "request.path.urlDecodeUni().lower().matches('${local.protected_paths_regex}') && !request.path.urlDecodeUni().lower().matches('${local.public_paths_regex}')"
      : "request.path.urlDecodeUni().lower().matches('${local.protected_paths_regex}')"
    )
    preview = false
  }

  # Preconfigured WAF rules (OWASP Core Rule Set 4.22), one rule per rule set.
  # With waf_preview they only log what they would block: the WordPress admin area sends HTML and
  # scripts that can look like attacks, so matches are reviewed in the logs before enforcing them.
  rules_waf = [
    for index, rule_set in var.waf_rule_sets : {
      priority    = 1000 + index
      description = "Preconfigured WAF: ${rule_set}"
      expression  = "evaluatePreconfiguredWaf('${rule_set}', {'sensitivity': ${var.waf_sensitivity}})"
      preview     = var.waf_preview
    }
  ]

  # Deny rules of each policy. Neither list may repeat a priority.
  public_deny_rules = concat(
    [local.rule_unknown_hosts, local.rule_xmlrpc],
    local.iap_enabled ? [local.rule_protected_paths] : [],
    local.rules_waf,
  )
  iap_deny_rules = concat([local.rule_unknown_hosts], local.rules_waf)

  # Login attempts per client IP. Only POST: loading the login page is not an attempt.
  # Attempts over rate_limit_threshold get a 429. An IP that goes over ban_threshold is banned for
  # ban_duration_sec: every login attempt from it gets a 429 until then. The rest of the site keeps
  # working for that IP. It goes in the policy of the backend that serves the login: the IAP one
  # when it exists, where it still matters, since a Google account with access, if compromised,
  # could try WordPress passwords.
  login_rule = {
    priority    = 200
    description = "Rate limit and ban login attempts per IP"
    expression  = "request.path.matches('^/+wp-login[.]php') && request.method == 'POST'"
  }
}

# Security policy of the public backend service.
resource "google_compute_security_policy" "wordpress" {
  name        = local.names.security_policy
  description = "WordPress: blocks unknown hosts, xmlrpc.php and protected paths outside IAP, limits login attempts, preconfigured WAF rules"
  type        = "CLOUD_ARMOR"

  dynamic "rule" {
    for_each = { for deny_rule in local.public_deny_rules : deny_rule.priority => deny_rule }
    content {
      action      = "deny(403)"
      priority    = rule.value.priority
      description = rule.value.description
      preview     = rule.value.preview
      match {
        expr {
          expression = rule.value.expression
        }
      }
    }
  }

  # Login rate limit, only when the login is not behind IAP (see local.login_rule).
  dynamic "rule" {
    for_each = local.iap_enabled ? [] : [local.login_rule]
    content {
      action      = "rate_based_ban"
      priority    = rule.value.priority
      description = rule.value.description
      match {
        expr {
          expression = rule.value.expression
        }
      }
      rate_limit_options {
        conform_action   = "allow"
        exceed_action    = "deny(429)"
        enforce_on_key   = "IP"
        ban_duration_sec = var.login_ban_duration_sec
        rate_limit_threshold {
          count        = var.login_rate_limit_count
          interval_sec = var.login_rate_limit_interval_sec
        }
        ban_threshold {
          count        = var.login_ban_threshold_count
          interval_sec = var.login_ban_interval_sec
        }
      }
    }
  }

  # Default rule, required by Cloud Armor: allow what no rule above matched.
  rule {
    action      = "allow"
    priority    = 2147483647
    description = "Default rule: allow"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}

# Security policy of the backend behind IAP. It runs before IAP, so it also sees the requests IAP is
# about to reject: the host rule and the WAF stop them first.
resource "google_compute_security_policy" "iap" {
  count = local.iap_enabled ? 1 : 0

  name        = local.names.iap_policy
  description = "WordPress behind IAP: blocks unknown hosts, limits login attempts, preconfigured WAF rules"
  type        = "CLOUD_ARMOR"

  dynamic "rule" {
    for_each = { for deny_rule in local.iap_deny_rules : deny_rule.priority => deny_rule }
    content {
      action      = "deny(403)"
      priority    = rule.value.priority
      description = rule.value.description
      preview     = rule.value.preview
      match {
        expr {
          expression = rule.value.expression
        }
      }
    }
  }

  # Login rate limit (see local.login_rule). Same block as in the public policy; only one of the two
  # exists at a time.
  rule {
    action      = "rate_based_ban"
    priority    = local.login_rule.priority
    description = local.login_rule.description
    match {
      expr {
        expression = local.login_rule.expression
      }
    }
    rate_limit_options {
      conform_action   = "allow"
      exceed_action    = "deny(429)"
      enforce_on_key   = "IP"
      ban_duration_sec = var.login_ban_duration_sec
      rate_limit_threshold {
        count        = var.login_rate_limit_count
        interval_sec = var.login_rate_limit_interval_sec
      }
      ban_threshold {
        count        = var.login_ban_threshold_count
        interval_sec = var.login_ban_interval_sec
      }
    }
  }

  # Default rule, required by Cloud Armor: allow what no rule above matched.
  rule {
    action      = "allow"
    priority    = 2147483647
    description = "Default rule: allow"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}

# ==========================================
# 5. FIREWALL
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
