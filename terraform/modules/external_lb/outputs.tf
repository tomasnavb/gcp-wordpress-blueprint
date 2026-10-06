output "external_lb_ip" {
  description = "Reserved external IP address of the load balancer"
  value       = google_compute_global_address.external_ip.address
}
