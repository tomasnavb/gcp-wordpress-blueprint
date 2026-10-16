module "vpc_prod" {
  depends_on = [google_project_service.gcp_services]
  source     = "./modules/networking"

  # VPC
  vpc_name            = var.vpc_prod_name
  auto_create_subnets = false

  # Subnet
  subnet_name          = var.subnet_prod_name
  subnet_ip_cidr_range = var.subnet_prod_ip_cidr_range
  region               = var.subnet_prod_region

  # Cloud NAT
  enable_nat                         = true
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  enable_nat_log_config              = true
  nat_log_filter                     = "ERRORS_ONLY"

  # IAP SSH
  allow_ssh_from_iap   = true
  iap_fw_rule_priority = 1000
  iap_target_tags      = ["iap-ssh-access"]
}
