output "external_lb_ip" {
  description = "External load balancer IP address"
  value       = google_compute_address.external_lb.address
}

output "external_lb_region" {
  description = "External load balancer region"
  value       = var.region
}

