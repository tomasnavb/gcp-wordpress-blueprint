output "external_lb_ip" {
  description = "External IP address of the load balancer (reserved beforehand or created by this module)"
  value       = local.ip_address
}

output "certificate_name" {
  description = "Name of the Google-managed SSL certificate (changes with the domain list)"
  value       = google_compute_managed_ssl_certificate.https.name
}

output "security_policy_name" {
  description = "Name of the Cloud Armor security policy of the public backend service"
  value       = google_compute_security_policy.wordpress.name
}

output "iap_backend_service_name" {
  description = "Name of the backend service behind IAP (null when iap_protected_paths is empty)"
  value       = local.iap_enabled ? google_compute_backend_service.mig_iap[0].name : null
}

output "iap_security_policy_name" {
  description = "Name of the Cloud Armor security policy of the backend behind IAP (null when iap_protected_paths is empty)"
  value       = local.iap_enabled ? google_compute_security_policy.iap[0].name : null
}
