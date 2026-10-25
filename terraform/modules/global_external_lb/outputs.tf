output "external_lb_ip" {
  description = "External IP address of the load balancer (reserved beforehand or created by this module)"
  value       = local.ip_address
}

output "certificate_name" {
  description = "Name of the Google-managed SSL certificate (changes with the domain list)"
  value       = google_compute_managed_ssl_certificate.https.name
}

output "security_policy_name" {
  description = "Name of the Cloud Armor security policy of the backend service"
  value       = google_compute_security_policy.wordpress.name
}
