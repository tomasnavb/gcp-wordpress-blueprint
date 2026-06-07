variable "subnet_name" {
  description = "Name for the subnet specific to the Load Balancer"
  type        = string
  default     = "lb-default-subnet"

}

variable "region" {
  type = string
}

variable "vpc_id" {
  description = "VPC ID (self link) where the external LB proxy-only subnet is created"
  type        = string
}

variable "dedicated_subnet_cidr" {
  description = "CIDR block for the external LB proxy-only subnet (REGIONAL_MANAGED_PROXY)"
  type        = string
}

variable "subnet_role" {
  description = "Role for the subnet. Active for currently in use for Envoy-based load-balancer"
  type        = string
  default     = "ACTIVE"
}

variable "ip_address_name" {
  description = "The external IP assigned to the External Load Balancer Proxy"
  type        = string
  default     = "external-proxy-lb-ip"
}

variable "url_map_name" {
  description = "Name for the URL map resource"
  type        = string
  default     = "url-map"
}

variable "health_check_name" {
  description = "Name for the health check resource"
  type        = string
  default     = "health-check"
}

variable "http_health_check_port" {
  description = "Port number for the HTTP health check"
  type        = number
  default     = 80
}

variable "backend_service_name" {
  description = "Name for the backend service resource"
  type        = string
  default     = "backend-service"
}

variable "mig_instance_group" {
  description = "Self link of the instance group"
  type        = string
}

variable "backend_service_protocol" {
  description = "Protocol for the backend service"
  type        = string
  default     = "HTTP"
}

variable "load_balancing_scheme" {
  description = "Load balancing scheme for the backend service"
  type        = string
  default     = "EXTERNAL_MANAGED"
}

variable "listener_port" {
  description = "External port that the regional HTTP(S) load balancer listens on (e.g. 80)"
  type        = number
  default     = 80
}

variable "balancing_mode" {
  description = "Balacing mode type"
  type        = string
}

variable "capacity_scaler" {
  description = "Capacity scaler value"
  type        = number
  default     = 1.0
}


variable "lb_name" {
  description = "Name for the load balancer"
  type        = string
  default     = "http-proxy-external-lb"
}

locals {
  subnet_purpose        = "REGIONAL_MANAGED_PROXY"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  lb_suffix             = "-external-lb"
  fr_full_name          = "${var.lb_name}-forwarding-rule"
  ip_protocol           = "TCP"
}
