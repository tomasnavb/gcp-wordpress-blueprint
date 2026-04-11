module "vpc_prod" {
  source = "./modules/networking"

  vpc_name             = var.vpc_prod_name
  subnet_name          = var.subnet_prod_name
  subnet_region        = var.subnet_prod_region
  subnet_ip_cidr_range = var.subnet_prod_ip_cidr_range
  enable_nat           = true
}

module "vpc_mgmt" {
  source = "./modules/networking"

  vpc_name             = var.vpc_mgmt_name
  subnet_name          = var.subnet_mgmt_name
  subnet_region        = var.subnet_mgmt_region
  subnet_ip_cidr_range = var.subnet_mgmt_ip_cidr_range
  enable_nat           = true
}


