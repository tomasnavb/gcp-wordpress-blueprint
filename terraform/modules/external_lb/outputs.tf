output "external_lb_ip" {
  description = "Reserved external IP address of the load balancer"
  value       = google_compute_address.external_ip.address
}

output "lb_subnet_ip_range" {
  description = "IP CIDR range of the proxy-only subnet created for the load balancer"
  value       = google_compute_subnetwork.external_lb_proxy.ip_cidr_range
}
