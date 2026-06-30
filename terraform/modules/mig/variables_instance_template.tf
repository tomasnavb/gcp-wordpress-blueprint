variable "region" {
  description = "GCP region for the instance template and MIG (regional deployment for HA)"
  type        = string
}

variable "template_name_prefix" {
  description = "Name prefix for the instance template (a timestamp suffix is auto-appended on each update)"
  type        = string
}

variable "machine_type" {
  description = "Machine type for WordPress instances (e.g. e2-standard-2)"
  type        = string
}

variable "source_image" {
  description = "Full path to the golden image built by Packer (projects/<project>/global/images/family/<family>)"
  type        = string
}

variable "disk_size_gb" {
  description = "Boot disk size in GB for each instance"
  type        = number
}

variable "disk_type" {
  description = "Boot disk type (pd-standard, pd-ssd, pd-balanced)"
  type        = string
}

variable "network" {
  description = "Self-link of the VPC network to attach instances to"
  type        = string
}

variable "subnetwork" {
  description = "Name or self-link of the subnetwork to attach instances to"
  type        = string
}

variable "startup_script" {
  description = "Startup script content executed on each instance boot"
  type        = string
}

variable "tags" {
  description = "Network tags applied to instances (used for firewall rule targeting)"
  type        = list(string)
}

variable "service_account_email" {
  description = "Email of the service account attached to each instance"
  type        = string
}
