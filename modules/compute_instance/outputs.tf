output "vm_self_link" {
  description = "The self_link for the VM instance"
  value       = google_compute_instance.gce_instance.self_link
}

output "instance_id" {
  description = "The generated ID for the VM instance"
  value       = google_compute_instance.gce_instance.id
}

output "instance_name" {
  description = "The name of the VM instance"
  value       = google_compute_instance.gce_instance.name

}
output "instances_tags" {
  description = "The tags applied to the VM instance"
  value       = google_compute_instance.gce_instance.tags

}
