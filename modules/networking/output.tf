# VPC network outputs
output "vpc_id" {
  value = google_compute_network.vpc.id
  description = "ID of the VPC network"
}

# Subnet outputs
output "subnet_name" {
    description = "The name of the subnet"
    value = google_compute_subnetwork.subnet.name
    
}

output "subnet_network" {
    description = "The VPC network to which the subnet belongs"
    value = google_compute_subnetwork.subnet.network
}

output "subnet_region" {
    description = "The region of the subnet"
    value = google_compute_subnetwork.subnet.region
}

output "subnet_ip_cidr_range" {
    description = "The IP CIDR range of the subnet"
    value = google_compute_subnetwork.subnet.ip_cidr_range
}