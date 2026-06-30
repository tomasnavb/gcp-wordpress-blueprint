# Production VPC
variable "vpc_prod_name" {
  description = "Name for the production VPC network"
  type        = string
}

variable "subnet_prod_name" {
  description = "Name for the production subnet"
  type        = string
}

variable "subnet_prod_region" {
  description = "GCP region for the production subnet"
  type        = string
}

variable "subnet_prod_ip_cidr_range" {
  description = "IP CIDR range for the production subnet"
  type        = string
  default     = "10.0.0.0/24"
}

# Management VPC
variable "vpc_mgmt_name" {
  description = "Name for the management VPC network"
  type        = string
}

variable "subnet_mgmt_name" {
  description = "Name for the management subnet"
  type        = string
}

variable "subnet_mgmt_region" {
  description = "GCP region for the management subnet"
  type        = string
}

variable "subnet_mgmt_ip_cidr_range" {
  description = "IP CIDR range for the management subnet"
  type        = string
  default     = "192.168.1.0/24"
}
