variable "region" {
  description = "GCP region for all load balancer resources"
  type        = string
}

variable "vpc_id" {
  description = "Self-link of the VPC network where the proxy-only subnet and forwarding rule are created"
  type        = string
}

variable "dedicated_subnet_cidr" {
  description = "IP CIDR block for the proxy-only subnet (REGIONAL_MANAGED_PROXY purpose)"
  type        = string
}

variable "subnet_name" {
  description = "Base name for the proxy-only subnet (the module appends '-external-lb' as suffix)"
  type        = string
}

variable "subnet_role" {
  description = "Role for the proxy-only subnet (ACTIVE for the subnet currently handling traffic)"
  type        = string
}

variable "ip_address_name" {
  description = "Base name for the reserved external IP address resource (module appends '-external-lb')"
  type        = string
}

variable "lb_name" {
  description = "Name for the regional HTTP proxy (also used as base for the forwarding rule name)"
  type        = string
}

variable "listener_port" {
  description = "External port the load balancer listens on (e.g. 80 for HTTP)"
  type        = number
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

variable "capacity_scaler" {
  description = "Multiplier applied to the backend's capacity (1.0 = 100%)"
  type        = number
}
