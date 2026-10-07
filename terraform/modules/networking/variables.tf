variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "auto_create_subnets" {
  description = "Whether to auto-create subnetworks (always false for custom-mode VPCs)"
  type        = bool
}

variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
}

variable "region" {
  description = "Region for the subnet, Cloud Router, and Cloud NAT"
  type        = string
}

variable "subnet_ip_cidr_range" {
  description = "IP CIDR range of the subnet"
  type        = string
}

variable "enable_nat" {
  description = "Whether to create a Cloud Router and Cloud NAT for outbound internet access"
  type        = bool
}

variable "nat_ip_allocate_option" {
  description = "How external IPs are allocated for NAT (AUTO_ONLY or MANUAL_ONLY)"
  type        = string
}

variable "source_subnetwork_ip_ranges_to_nat" {
  description = "Which subnet IP ranges are subject to NAT translation"
  type        = string
}

variable "enable_nat_log_config" {
  description = "Whether to enable Cloud NAT logging"
  type        = bool
}

variable "nat_log_filter" {
  description = "NAT log filter level (ALL, ERRORS_ONLY, or TRANSLATIONS_ONLY)"
  type        = string
}

variable "allow_ssh_from_iap" {
  description = "Whether to create a firewall rule allowing SSH access via IAP"
  type        = bool
}

variable "iap_fw_rule_priority" {
  description = "Priority for the IAP SSH firewall rule (lower number = higher priority)"
  type        = number
}

variable "iap_target_tags" {
  description = "Network tags that the IAP SSH firewall rule applies to"
  type        = list(string)
}
