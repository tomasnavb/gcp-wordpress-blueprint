# Compute resources for wordpress-site on Google Cloud project.

/*Wordpress Management VM - This VM instance is intended for management purposes of the CloudSQL database. Secure access to the database
is provided through the Cloud SQL Auth Proxy running on this VM. Cloud Auth Proxy and Wordpress installed via startup script. Secure access 
for the VM via IAP. Using default values for boot-disk-image (debian-cloud/debian-11), 
boot-disk-size-gb (10GB), and boot-disk-type (pd-standard) and for has_external_ip (false). */
module "wordpress_vm_mgmt" {
  depends_on                     = [google_project_service.gcp_services]
  source                         = "./modules/compute_instance"
  instance_name                  = var.vm_mgmt_name
  instance_machine_type          = var.vm_mgmt_machine_type
  instance_tags                  = local.vm_mgmt_tags
  vpc_id                         = module.vpc_mgmt.id
  subnet_id                      = module.vpc_mgmt.subnet_id
  start_up_script_path           = local.vm_mgmt_startup_script_path
  instance_service_account_email = google_service_account.mgmt_vm.email
  boot_disk_image                = var.vm_boot_disk_image
}

/* Wordpress Production VM - This instance is dedicated to serving the site's web traffic. It connects to the Cloud SQL database
via internal IP to optimize latency and security. The instance does not have an external IP; internet traffic is handled by
a Load Balancer that acts as an intermediary to protect the machine's identity and distribute the load. It uses default
values for the boot disk (Debian 11, 10GB, pd-standard)  and for has_external_ip (false). */
module "wordpress_vm_prod" {
  depends_on                     = [google_project_service.gcp_services]
  source                         = "./modules/compute_instance"
  instance_name                  = var.vm_prod_name
  instance_machine_type          = var.vm_prod_machine_type
  instance_tags                  = local.vm_prod_tags
  vpc_id                         = module.vpc_prod.id
  subnet_id                      = module.vpc_prod.subnet_id
  start_up_script_path           = local.vm_prod_startup_script_path
  instance_service_account_email = google_service_account.prod_vm.email
  boot_disk_image                = var.vm_boot_disk_image

}

# MIG
module "wordpress_regional_mig" {
  source = "./modules/mig"

  # Basic configs
  lb_utilization_target     = "."
  disk_size_gb              = 10
  min_replicas              = 1
  max_replicas              = 3
  image_family              = "tanto"
  subnetwork                = ""
  request_path              = ""
  mig_name                  = ""
  name_prefix               = ""
  region                    = ""
  base_instance_name        = ""
  health_check_port         = ""
  autoscaler_region         = ""
  time_window_sec           = ""
  distribution_policy_zones = ""
  tags                      = ""
  cooldown_period           = ""
  healthy_threshold         = ""
  max_scaled_in_replicas    = ""
  health_check_name         = ""
  network                   = ""
  project_id                = ""
  check_interval_sec        = 1
  autoscaler_name           = ""
  unhealthy_threshold       = ""
  timeout_sec               = ""

}

/* External Load Balancer for the wordpress_vm_prod*/
module "external_lb" {
  source                = "./modules/external_lb"
  region                = var.subnet_prod_region
  dedicated_subnet_cidr = var.lb_dedicated_ip_cidr
  balancing_mode        = "RATE"
  mig_instance_group    = "MIG"
  vpc_id                = module.vpc_prod.id

}
