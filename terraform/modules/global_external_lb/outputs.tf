output "external_lb_ip" {
  description = "External IP address of the load balancer (reserved beforehand or created by this module)"
  value       = local.ip_address
}
