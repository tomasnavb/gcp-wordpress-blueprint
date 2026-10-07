# Management VM
variable "vm_mgmt_name" {
  description = "A given name for the compute instance management VM"
  type        = string
}

variable "vm_mgmt_machine_type" {
  description = "Machine type for management VM running CloudSQL Auth Proxy only (e2-medium sufficient for admin access workloads)"
  type        = string
}


# External Application Load Balancer
variable "lb_use_reserved_ip" {
  description = "true: the load balancer uses the global IP reserved by configs/setup.sh (RESERVE_LB_IP=true), which survives terraform destroy. false: Terraform creates and destroys the IP with the load balancer"
  type        = bool
}

variable "domain_names" {
  description = "Domain names included in the Google-managed SSL certificate of the load balancer. Each needs a DNS A record pointing to the load balancer IP"
  type        = list(string)
}
