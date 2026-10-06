variable "project_id" {
  description = "Project ID used to allow Load Balancer Firewall Rules"
  type        = string
}

variable "network_self_link" {
  description = "Network Self Link to allow Load balancer Firewall Rules"
  type        = string
}

variable "target_tags" {
  description = "Target tags referencing the backend Compute Instances"
  type        = list(string)
}

variable "ip_address_name" {
  description = "Base name for the reserved external IP address resource (module appends '-external-lb')"
  type        = string
}

variable "lb_name" {
  description = "Name for the regional HTTP proxy (also used as base for the forwarding rule name)"
  type        = string
}

variable "domain_names" {
  description = "Domains to include into the Google Managed SSL ceritificates"
  type        = list(string)
}

variable "url_map_name" {
  description = "Base name for the URL map resource (module appends '-external-lb')"
  type        = string
}

variable "health_check_name" {
  description = "Base name for the regional health check resource (module appends '-external-lb')"
  type        = string
}

variable "http_health_check_port" {
  description = "TCP port the regional health check probes on the backend instances"
  type        = number
}

variable "backend_service_name" {
  description = "Name for the regional backend service resource"
  type        = string
}

variable "backend_service_protocol" {
  description = "Protocol used between the load balancer and backend instances (HTTP or HTTPS)"
  type        = string
}

variable "load_balancing_scheme" {
  description = "Load balancing scheme applied to both the forwarding rule and backend service (EXTERNAL_MANAGED)"
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
