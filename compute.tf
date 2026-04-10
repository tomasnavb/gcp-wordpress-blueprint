# Production VM Instance - No External IP, IAP Access Only
resource "google_compute_instance" "prod" {
  name         = var.vm_prod_name
  machine_type = var.vm_prod_machine_type

  boot_disk {
    initialize_params {
      image = var.vm_boot_disk_image
      size  = ""
      type  = ""
    }
  }

  network_interface {
    network = google_compute_network.prod.name
  }

  tags = ["prod-vm"]

}

# Management VM Instance - No External IP, IAP Access Only, CloudSQL Auth Proxy Installed
resource "google_compute_instance" "mgmt" {
  name         = var.vm_mgmt_name
  machine_type = var.vm_mgmt_machine_type

  boot_disk {
    initialize_params {
      image = var.vm_boot_disk_image
      size  = ""
      type  = ""
    }
  }

  network_interface {
    network = google_compute_network.mgmt.name
  }

  attached_disk {
    source = google_compute_disk.mgmt.self_link

  }

  service_account {
    email  = google_service_account.mgmt_vm
    scopes = ["cloud-platform"]
  }

  tags = ["mgmt-vm"]

}
