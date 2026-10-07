output "load_balancer_ip" {
  description = "External IP of the load balancer. The DNS A record of every domain must point to it"
  value       = module.global_external_lb.external_lb_ip
}

output "site_urls" {
  description = "URLs WordPress is served on once the certificate is active"
  value       = [for domain in var.domain_names : "https://${domain}"]
}

output "ssl_certificate_name" {
  description = "Managed certificate name. Check its status with: gcloud compute ssl-certificates describe <name> --global --format='value(managed.status, managed.domainStatus)'"
  value       = module.global_external_lb.certificate_name
}
