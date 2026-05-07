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

variable "subnet_cidr" {
  description = "CIDR block for the external LB proxy-only subnet (REGIONAL_MANAGED_PROXY)"
  type        = string
  default     = "10.128.0.0/23"
}

variable "subnet_purpose" {
  description = "The purpose of the subnet"
  type        = string
  default     = "REGIONAL_MANAGED_PROXY"

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

variable "ip_address_region" {
  description = "Region where the external load balancer and its components will be created"
  type        = string
  default     = "europe-west9"
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

variable "backend_group_name" {
  description = "Name for the backend instance group"
  type        = string
  default     = "backend-group"
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

variable "umig_zone" {
  description = "Specified zone for the Unamanged Instance Group"
  type        = string
  default     = "europe-west9"
}

variable "umig_instances" {
  description = "List of instances to add on the umig instances group"
  type        = list(string)
}

variable "lb_name" {
  description = "Name for the load balancer"
  type        = string
  default     = "http-proxy-external-lb"
}

locals {
  lb_suffix      = "-external-lb"
  fr_full_name   = "${var.lb_name}-forwarding-rule"
  fr_ip_protocol = "TCP"
}
