resource "google_compute_instance" "gce_instance" {
  name         = var.instance_name
  machine_type = var.instance_machine_type

  tags = var.instance_tags

  network_interface {
    network    = var.vpc_id
    subnetwork = var.subnet_id
    stack_type = var.nic_stack_type
    dynamic "access_config" {
      for_each = has_external_ip ? [1] : []
      content {
      }

    }
  }

  boot_disk {
    initialize_params {
      image = var.boot_disk_image
      size  = var.boot_disk_size_gb
      type  = var.boot_disk_type
    }
  }

  metadata = {
    "startup-script" = file(var.start_up_script_path)
  }

  service_account {
    email  = var.instance_service_account_email
    scopes = local.sa_scope
  }

}
