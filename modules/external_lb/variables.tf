variable "external_lb_proxy_subnet_name" {
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

variable "external_lb_proxy_subnet_cidr" {
  description = "CIDR block for the external LB proxy-only subnet (REGIONAL_MANAGED_PROXY)"
  type        = string
  default     = "10.128.0.0/23"
}

variable "external_lb_proxy_subnet_purpose" {
  description = "The purpose of the subnet"
  type        = string
  default     = "REGIONAL_MANAGED_PROXY"

}

variable "external_lb_proxy_subnet_role" {
  description = "Role for the subnet. Active for currently in use for Envoy-based load-balancer"
  type        = string
  default     = "ACTIVE"
}

variable "external_lb_ip_address_name" {
  description = "The external IP assigned to the External Load Balancer Proxy"
  type        = string
  default     = "external-proxy-lb-ip"
}

variable "listener_port" {
  description = "External port that the regional HTTP(S) load balancer listens on (e.g. 80)"
  type        = number
  default     = 80
}

variable "umig_instances" {
  description = "List of instances to add on the umig instances group"
  type        = list(string)
}
