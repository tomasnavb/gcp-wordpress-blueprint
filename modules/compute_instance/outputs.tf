output "instance_id" {
  description = "The generated ID for the VM instance"
  value       = google_compute_instance.vm.id
}

output "instance_name" {
  description = "The name of the VM instance"
  value       = google_compute_instance.vm.name

}
output "instances_tags" {
  description = "The tags applied to the VM instance"
  value       = google_compute_instance.vm.tags

}