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

module "vpc_mgmt" {
  depends_on = [google_project_service.gcp_services]
  source     = "./modules/networking"

  # VPC
  vpc_name            = var.vpc_mgmt_name
  auto_create_subnets = false

  # Subnet
  subnet_name          = var.subnet_mgmt_name
  subnet_ip_cidr_range = var.subnet_mgmt_ip_cidr_range
  region               = var.subnet_mgmt_region

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

resource "google_compute_network_peering" "peering-prod-mgmt" {
  name         = "peering-prod-mgmt"
  network      = module.vpc_prod.vpc_self_link
  peer_network = module.vpc_mgmt.vpc_self_link
}

resource "google_compute_network_peering" "peering-mgmt-prod" {
  name         = "peering-mgmt-prod"
  network      = module.vpc_mgmt.vpc_self_link
  peer_network = module.vpc_prod.vpc_self_link
}
