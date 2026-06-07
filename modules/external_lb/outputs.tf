output "external_lb_ip" {
  description = "External load balancer IP address"
  value       = google_compute_address.external_ip.address
}

output "lb_subnet_ip_range" {
  description = "value"
  value       = google_compute_subnetwork.external_lb_proxy.ip_cidr_range
}
