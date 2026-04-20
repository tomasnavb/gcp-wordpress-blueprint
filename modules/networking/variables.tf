# VPC network variables
variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "wordpress-site-vpc"

}

# Subnet variables
variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
}

variable "subnet_region" {
  description = "Region of the subnet"
  type        = string
}

variable "subnet_ip_cidr_range" {
  description = "IP CIDR range of the subnet"
  type        = string
}

# Cloud Router variables
variable "enable_nat" {
  description = "Whether to enable NAT for the Cloud Router"
  type        = bool
}

variable "allow_ssh_from_iap" {
  description = "Allow IAP TCP forwarding from the external LB to the backend instances"
  type        = bool
  default     = false
}

variable "allow_external_lb" {
  description = "Allow external Load Balancer IP ranges to communicate with backend services"
  type        = bool
  default     = false
}

locals {
  iap_allow_ssh_direciton = "INGRESS"
  iap_ip_ranges           = ["35.235.240.0/20"]
}