variable "vpc_name" {
    description = "Name of the VPC network"
    type        = string
    default     = "wordpress-site-vpc"
  
}

resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
}

output "vpc_id" {
  value = google_compute_network.vpc.id
  description = "ID of the VPC network"
}