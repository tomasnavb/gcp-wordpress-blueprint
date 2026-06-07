variable "vm_prod_name" {
  description = "A given name for the compute instance production VM"
  type        = string
}


# Management VM
variable "vm_mgmt_name" {
  description = "A given name for the compute instance management VM"
  type        = string
  default     = "mgmt"
}

variable "vm_mgmt_machine_type" {
  description = "Machine type for management VM running CloudSQL Auth Proxy only (e2-medium sufficient for admin access workloads)"
  type        = string
  default     = "e2-medium"
}

variable "vm_prod_machine_type" {
  description = "Machine type for production VM running Wordpress (e2-standard-2 recommended for moderate traffic)"
  type        = string
  default     = "e2-standard-2"
}

variable "vm_boot_disk_image" {
  description = "Boot disk image for production and management VM"
  type        = string
  default     = "debian-cloud/debian-12"
}


# External Proxy Load Balancer
variable "lb_dedicated_ip_cidr" {
  description = "IP CIDR range for the external load balancer proxy subnet"
  type        = string
  default     = "10.0.1.0/24"
}
