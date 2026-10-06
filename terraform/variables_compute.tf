# Management VM
variable "vm_mgmt_name" {
  description = "A given name for the compute instance management VM"
  type        = string
}

variable "vm_mgmt_machine_type" {
  description = "Machine type for management VM running CloudSQL Auth Proxy only (e2-medium sufficient for admin access workloads)"
  type        = string
}


# External Proxy Load Balancer
variable "lb_dedicated_ip_cidr" {
  description = "IP CIDR range for the external load balancer proxy subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "domain_names" {
  description = "Domains names to include into the Google Managed SSL certificates for the External LB"
  type        = list(string)
  default     = ["wordpress.tomasnavarro.dev"]
}
