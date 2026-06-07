variable "vpc_prod_name" {
  description = "Main name for the VPC production network"
  type        = string
}

variable "subnet_prod_name" {
  description = ""
  type        = string
}

variable "subnet_prod_region" {
  description = "value"
  type        = string
  default     = "europe-west9"

}

variable "subnet_prod_ip_cidr_range" {
  description = "value"
  type        = string
  default     = "10.0.0.0/24"
}


variable "vpc_mgmt_name" {
  description = "Main name for the VPC management network"
  type        = string
}

variable "subnet_mgmt_name" {
  description = "value"
  type        = string

}

variable "subnet_mgmt_region" {
  description = "value"
  type        = string
  default     = "europe-west9"

}

variable "subnet_mgmt_ip_cidr_range" {
  description = "value"
  type        = string
  default     = "192.168.1.0/24"
}