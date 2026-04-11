output "vm_instance_id" {
    description = "The generated ID for the VM instance"
    value = google_compute_instance.vm.id
}

output "vm_instance_name" {
    description = "The name of the VM instance"
    value = google_compute_instance.vm.name
  
}

output "vm_instance_subnet_range" {
    description = "The IP range of the subnet to which the VM instance is connected"
    value = google_compute_subnetwork.subnet.ip_cidr_range
}

output "vm_tags" {
    description = "The tags applied to the VM instance"
    value = google_compute_instance.vm.tags
  
}