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
  auto_create_subnets     = false
  iap_allow_ssh_direction = "INGRESS"
  iap_ip_ranges           = ["35.235.240.0/20"]
  allow_ssh_iap_name      = "allow-iap-ssh"
  allow_external_lb_name  = "allow-external-lb"
  default_priority        = 1000
  tcp_traffic_port        = 80
  tcp_protocol            = "tcp"
  ingress_fr              = "INGRESS"
  ssh_port                = 22
  iap_target_tags         = ["iap-ssh-access"]
  lb_source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22",
    "10.128.0.0/23"
  ]
  backend_tags             = ["backend-service"]
  router_name              = "${var.vpc_name}-router"
  nat_name                 = "${google_compute_router.vpc_router.name}-nat"
  nat_ip_allocation_option = "AUTO_ONLY"
  nat_source_subnets       = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  enable_log_config        = true
  log_filter               = "ERRORS_ONLY"
}
