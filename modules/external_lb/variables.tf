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
}
variable "listener_port" {
  description = "External port that the regional HTTP(S) load balancer listens on (e.g. 80)"
  type        = number
  default     = 80
}

variable "umig_instances" {
  description = "List of instances to add on the umig instances group"
  type = list(string)
}