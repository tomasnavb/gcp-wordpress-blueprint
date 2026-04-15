# VPC prod with a subnet for the VM unmanaged instance group
module "vpc_prod" {
  depends_on = [google_project_service.gcp_services]
  source     = "./modules/networking"

  vpc_name             = var.vpc_prod_name
  subnet_name          = var.subnet_prod_name
  subnet_region        = var.subnet_prod_region
  subnet_ip_cidr_range = var.subnet_prod_ip_cidr_range
  enable_nat           = true
}

module "vpc_mgmt" {
  depends_on = [google_project_service.gcp_services]
  source     = "./modules/networking"

  vpc_name             = var.vpc_mgmt_name
  subnet_name          = var.subnet_mgmt_name
  subnet_region        = var.subnet_mgmt_region
  subnet_ip_cidr_range = var.subnet_mgmt_ip_cidr_range
  enable_nat           = true
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




