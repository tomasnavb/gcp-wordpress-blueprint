# External Application Load Balancer
variable "lb_use_reserved_ip" {
  description = "true: the load balancer uses the global IP reserved by configs/setup.sh (RESERVE_LB_IP=true), which survives terraform destroy. false: Terraform creates and destroys the IP with the load balancer"
  type        = bool
}

# Passed by the pipeline from the _DOMAIN_NAMES substitution, like project_id: it is never written
# in the repository, so a fork cannot deploy with someone else's domain by mistake. A string and not
# a list, because a Cloud Build substitution holds a string; local.domain_names splits it.
variable "domain_names" {
  description = "Domain names the load balancer serves, comma separated (example.com,www.example.com), included in its Google-managed SSL certificate; any other Host header gets a 403. Each needs a DNS A record pointing to the load balancer IP. The first one is the site address WordPress uses (WP_HOME and WP_SITEURL). Passed by the pipeline from _DOMAIN_NAMES"
  type        = string

  validation {
    condition     = alltrue([for domain in split(",", var.domain_names) : can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?([.][a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", trimspace(domain)))])
    error_message = "domain_names must be one or more lowercase domains, comma separated, such as example.com,www.example.com. Set it with the _DOMAIN_NAMES substitution in Cloud Build or TF_VAR_domain_names locally."
  }
}

variable "waf_preview" {
  description = "true: the preconfigured Cloud Armor WAF rules only log what they would block, to review false positives. false: they block. The xmlrpc.php block and the login rate limit always apply"
  type        = bool
}
