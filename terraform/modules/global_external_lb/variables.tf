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

variable "ip_address_name" {
  description = "Base name for the reserved external IP address resource (module appends '-global-external-lb')"
  type        = string
}

variable "lb_name" {
  description = "Base name of the load balancer. Proxies, forwarding rules, the redirect URL map, the certificate, the SSL policy and the firewall rule are named after it"
  type        = string
}

variable "domain_names" {
  description = "Domains included in the Google-managed SSL certificate"
  type        = list(string)
}

variable "ssl_policy_profile" {
  description = "Cipher profile of the SSL policy (COMPATIBLE, MODERN or RESTRICTED)"
  type        = string
}

variable "min_tls_version" {
  description = "Minimum TLS version accepted from clients (TLS_1_0, TLS_1_1 or TLS_1_2)"
  type        = string
}

variable "url_map_name" {
  description = "Base name for the URL map resource (module appends '-global-external-lb')"
  type        = string
}

variable "health_check_name" {
  description = "Base name for the health check resource (module appends '-global-external-lb')"
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

variable "backend_service_name" {
  description = "Name for the backend service resource"
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
