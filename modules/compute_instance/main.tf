resource "google_compute_instance" "vm" {
  name         = var.vm_instance_name
  machine_type = var.vm_machine_type

  tags = var.instance_tags

  network_interface {
    network = var.vpc_id
    subnetwork = var.subnet_id
  }

  boot_disk {
    initialize_params {
      image = var.boot_disk_image
      size  = var.boot_disk_size_gb
      type  = var.boot_disk_type
    }
  }

  metadata = {
    "startup_script" = var.start_up_script_path
  }

  service_account {
    email = var.vm_service_account_email
    scopes = ["cloud-platform"]
  }

}
