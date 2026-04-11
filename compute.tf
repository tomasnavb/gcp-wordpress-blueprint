module "wordpress_vm_mgmt" {
  source = "./modules/compute_instance"
  vm_instance_name = "wordpress-vm-mgmt"
  vm_machine_type = "e2-medium"
  instance_tags = ["management", "web-server", "no-external-ip"]
  vpc_id = google_compute_network.mgmt.id
  subnet_id = google_compute_subnetwork.mgmt.id
  boot_disk_image = "debian-cloud/debian-11"
  boot_disk_size_gb = "10GB"
  boot_disk_type = "pd-standard"
  start_up_script_path = "${path.module}/scripts/startup-mgmt.sh"
  vm_service_account_email = google_service_account.wordpress_vm_mgmt.email
}
