# Compute resources for wordpress-site on Google Cloud project.

/*Wordpress Management VM - This VM instance is intended for management purposes of the CloudSQL database. Secure access to the database
is provided through the Cloud SQL Auth Proxy running on this VM. Cloud Auth Proxy and Wordpress installed via startup script. Secure access 
for the VM via IAP. Using default values for boot-disk-image (debian-cloud/debian-11), 
boot-disk-size-gb (10GB), and boot-disk-type (pd-standard) and for has_external_ip (false). */
module "wordpress_vm_mgmt" {
  depends_on               = [google_project_service.gcp_services]
  source                   = "./modules/compute_instance"
  vm_instance_name         = var.vm_mgmt_name
  vm_machine_type          = var.vm_mgmt_machine_type
  instance_tags            = ["management", "no-external-ip"]
  vpc_id                   = google_compute_network.mgmt.id
  subnet_id                = google_compute_subnetwork.mgmt.id
  start_up_script_path     = "${path.module}/scripts/startup-mgmt.sh"
  vm_service_account_email = google_service_account.wordpress_vm_mgmt.email
}

/* Wordpress Production VM - This instance is dedicated to serving the site's web traffic. It connects to the Cloud SQL database
via internal IP to optimize latency and security. The instance does not have an external IP; internet traffic is handled by
a Load Balancer that acts as an intermediary to protect the machine's identity and distribute the load. It uses default
values for the boot disk (Debian 11, 10GB, pd-standard)  and for has_external_ip (false). */
module "wordpress_vm_prod" {
  depends_on               = [google_project_service.gcp_services]
  source                   = "./modules/compute_instance"
  vm_instance_name         = var.vm_prod_name
  vm_machine_type          = var.vm_prod_machine_type
  instance_tags            = ["production", "web-server", "no-external-ip"]
  vpc_id                   = google_compute_network.prod.id
  subnet_id                = google_compute_subnetwork.prod.id
  start_up_script_path     = "${path.module}/scripts/startup-prod.sh"
  vm_service_account_email = google_service_account.prod_vm.email

}

/* External Load Balancer for the wordpress_vm_prod*/
module "external_lb" {
  source                        = "./modules/external_lb"
  region                        = var.subnet_prod_region
  vpc_id                        = google_compute_network.prod.id
  external_lb_proxy_subnet_cidr = var.external_lb_proxy_subnet_cidr
  umig_instances                = [module.vm_instance_prod.vm_self_link]

}
