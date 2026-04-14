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

