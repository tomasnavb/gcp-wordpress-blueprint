# External Application Load Balancer
variable "lb_use_reserved_ip" {
  description = "true: the load balancer uses the global IP reserved by configs/setup.sh (RESERVE_LB_IP=true), which survives terraform destroy. false: Terraform creates and destroys the IP with the load balancer"
  type        = bool
}

variable "domain_names" {
  description = "Domain names the load balancer serves, included in its Google-managed SSL certificate; any other Host header gets a 403. Each needs a DNS A record pointing to the load balancer IP. The first one is the site address WordPress uses (WP_HOME and WP_SITEURL)"
  type        = list(string)
}

variable "waf_preview" {
  description = "true: the preconfigured Cloud Armor WAF rules only log what they would block, to review false positives. false: they block. The xmlrpc.php block and the login rate limit always apply"
  type        = bool
}
