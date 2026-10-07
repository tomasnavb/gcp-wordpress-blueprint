output "external_lb_ip" {
  description = "External IP address of the load balancer (reserved beforehand or created by this module)"
  value       = local.ip_address
}

output "certificate_name" {
  description = "Name of the Google-managed SSL certificate (changes with the domain list)"
  value       = google_compute_managed_ssl_certificate.https.name
}
