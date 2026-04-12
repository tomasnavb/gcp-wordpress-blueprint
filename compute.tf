# Compute resources for wordpress-site on Google Cloud project.

/*Wordpress Management VM - This VM instance is intended for management purposes of the CloudSQL database. 
Secure access for the VM via IAP. Using default values for boot-disk-image (debian-cloud/debian-11), 
boot-disk-size-gb (10GB), and boot-disk-type (pd-standard). */
module "wordpress_vm_mgmt" {
  source                   = "./modules/compute_instance"
  vm_instance_name         = var.vm_mgmt_name
  vm_machine_type          = var.vm_mgmt_machine_type
  instance_tags            = ["management", "web-server", "no-external-ip"]
  vpc_id                   = google_compute_network.mgmt.id
  subnet_id                = google_compute_subnetwork.mgmt.id
  start_up_script_path     = "${path.module}/scripts/startup-mgmt.sh"
  vm_service_account_email = google_service_account.wordpress_vm_mgmt.email
}

/* Wordpress Production VM */
module "vm_instance_prod" {
  source = "./modules/compute_instance"
  vm_instance_name = var.vm_prod_name
  vm_machine_type = var.vm_prod_machine_type
  instance_tags = ["production", "web-server"]
  vpc_id = google_compute_network.prod.id
  subnet_id = google_compute_subnetwork.prod.id
  start_up_script_path = "${path.module}/scripts/startup-prod.sh"
  vm_service_account_email = google_service_account.wordpress_vm_prod.email
  
}

module "external_lb" {
  source = "./modules/external_lb"
  region = var.subnet_prod_region
  vpc_id = google_compute_network.prod.id
  external_lb_proxy_subnet_cidr = var.external_lb_proxy_subnet_cidr
  umig_instances = [module.vm_instance_prod.vm_self_link]
  
}
