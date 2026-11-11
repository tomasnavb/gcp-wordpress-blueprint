variable "project_id" {
  description = "Project ID where the load balancer firewall rule is created"
  type        = string
}

variable "network_self_link" {
  description = "Self-link of the VPC network of the backends, where the firewall rule is created"
  type        = string
}

variable "backend_target_tags" {
  description = "Network tags of the backend instances the firewall rule applies to (must be present in the instance template tags)"
  type        = list(string)
}

variable "use_reserved_ip" {
  description = "true: use a global address reserved outside Terraform, looked up by name, which survives terraform destroy. false: create the address here and destroy it with the load balancer"
  type        = bool
}

variable "name_prefix" {
  description = "Prefix of every resource name. Names are <name_prefix>-<component>-<environment>, e.g. myapp-lb-ip-prod. With use_reserved_ip, the IP is looked up by that name"
  type        = string
}

variable "environment" {
  description = "Environment, last part of every resource name (dev or prod)"
  type        = string
}

variable "domain_names" {
  description = "Domains the load balancer serves, included in the Google-managed SSL certificate. Any other Host header gets a 403"
  type        = list(string)

  # Each name is written into the host rule and into a Cloud Armor regular expression, so only
  # plain hostnames are accepted: no wildcards, ports or other characters.
  validation {
    condition     = length(var.domain_names) > 0 && alltrue([for domain in var.domain_names : can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?([.][a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", domain))])
    error_message = "domain_names must hold at least one domain, each a lowercase hostname such as www.example.com."
  }
}

variable "ssl_policy_profile" {
  description = "Cipher profile of the SSL policy (COMPATIBLE, MODERN or RESTRICTED)"
  type        = string
}

variable "min_tls_version" {
  description = "Minimum TLS version accepted from clients (TLS_1_0, TLS_1_1 or TLS_1_2)"
  type        = string
}

variable "http_health_check_port" {
  description = "TCP port the health check probes on the backend instances"
  type        = number
}

variable "health_check_request_path" {
  description = "HTTP path the health check requests on the backend instances"
  type        = string
}

variable "backend_service_protocol" {
  description = "Protocol used between the load balancer and backend instances (HTTP or HTTPS)"
  type        = string
}

variable "backend_port_name" {
  description = "Named port of the instance group the backend service sends traffic to"
  type        = string
}

variable "backend_port" {
  description = "TCP port behind the named port, opened in the firewall rule for traffic from the load balancer"
  type        = number
}

variable "load_balancing_scheme" {
  description = "Load balancing scheme applied to both forwarding rules and the backend service (EXTERNAL_MANAGED)"
  type        = string
}

variable "mig_instance_group" {
  description = "Self-link of the regional MIG instance group to attach as the backend"
  type        = string
}

variable "balancing_mode" {
  description = "Backend balancing mode: RATE (requests per second) or UTILIZATION (CPU)"
  type        = string
}

variable "max_rate_per_instance" {
  description = "Maximum requests per second per backend instance (only applicable if balancing_mode is RATE)"
  type        = number
}

variable "capacity_scaler" {
  description = "Multiplier applied to the backend's capacity (1.0 = 100%)"
  type        = number
}

variable "project_number" {
  description = "Project number. Builds the name of the Google-managed service account the load balancer reads the private uploads bucket with"
  type        = string
}

variable "uploads_bucket_name" {
  description = "Cloud Storage bucket with the WordPress uploads, served through a backend bucket with Cloud CDN"
  type        = string
}

variable "uploads_path" {
  description = "URL path routed to the uploads bucket instead of the instances (e.g. /wp-content/uploads/*)"
  type        = string
}

variable "uploads_cdn_default_ttl" {
  description = "Seconds Cloud CDN caches an upload (FORCE_CACHE_ALL applies this TTL to every response)"
  type        = number
}

variable "uploads_cdn_client_ttl" {
  description = "Maximum seconds browsers may cache an upload"
  type        = number
}

variable "backend_cdn_default_ttl" {
  description = "Seconds Cloud CDN caches a static response from the instances that sets no TTL of its own"
  type        = number
}

variable "backend_cdn_max_ttl" {
  description = "Maximum seconds Cloud CDN caches a response from the instances, whatever TTL it sets"
  type        = number
}

variable "backend_cdn_client_ttl" {
  description = "Maximum seconds browsers may cache a static response from the instances"
  type        = number
}

variable "waf_rule_sets" {
  description = "Preconfigured Cloud Armor WAF rule sets to evaluate, e.g. sqli-v33-stable. One rule per set"
  type        = list(string)
}

variable "waf_sensitivity" {
  description = "Sensitivity level of the preconfigured WAF rules (1 = fewest false positives)"
  type        = number
}

variable "waf_preview" {
  description = "true: WAF rules only log what they would block. false: they block"
  type        = bool
}

variable "login_rate_limit_count" {
  description = "Login attempts (POST to wp-login.php) allowed per client IP in each interval"
  type        = number
}

variable "login_rate_limit_interval_sec" {
  description = "Interval in seconds of the login rate limit"
  type        = number
}

variable "login_ban_threshold_count" {
  description = "Login attempts per client IP within login_ban_interval_sec that get the IP banned"
  type        = number
}

variable "login_ban_interval_sec" {
  description = "Interval in seconds over which login_ban_threshold_count is counted"
  type        = number
}

variable "login_ban_duration_sec" {
  description = "Seconds a banned IP gets a 429 on every login attempt"
  type        = number
}

# IAP. Optional: an empty iap_protected_paths creates no IAP backend, no second security policy and
# no extra path rules.
variable "iap_protected_paths" {
  description = "Paths routed to a second backend service on the same instance group, behind IAP, e.g. /admin/* or /login.php. A path ending in /* covers everything under it. Empty: no IAP backend is created"
  type        = list(string)

  # Each path is written into a path rule and into a Cloud Armor regular expression, so only plain
  # paths are accepted: letters, digits, dots, dashes, underscores and slashes, optionally ending in /*.
  validation {
    condition     = alltrue([for path in var.iap_protected_paths : can(regex("^/[A-Za-z0-9._/-]*(/[*])?$", path))])
    error_message = "Each of iap_protected_paths must be a plain path starting with /, optionally ending in /*."
  }
}

variable "iap_public_paths" {
  description = "Exact paths under a protected prefix that stay on the public backend, e.g. /admin/ajax.php. Ignored when iap_protected_paths is empty"
  type        = list(string)

  validation {
    condition     = alltrue([for path in var.iap_public_paths : can(regex("^/[A-Za-z0-9._/-]*$", path))])
    error_message = "Each of iap_public_paths must be an exact plain path starting with /, without wildcards."
  }
}

variable "iap_members" {
  description = "Principals granted roles/iap.httpsResourceAccessor on the IAP backend, e.g. user:admin@example.com or group:admins@example.com"
  type        = list(string)

  validation {
    condition     = length(var.iap_protected_paths) == 0 || length(var.iap_members) > 0
    error_message = "iap_members must not be empty when iap_protected_paths is set: nobody could reach the protected paths."
  }
}
