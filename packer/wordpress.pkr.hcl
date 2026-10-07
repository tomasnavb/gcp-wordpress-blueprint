packer {
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = "~> 1.1"
    }
  }
}

# Temporary VM definition — destroyed after image is created
source "googlecompute" "wordpress" {
  project_id = var.project_id
  zone       = var.zone

  # Base image
  source_image_family      = "debian-12"
  source_image_project_id  = ["debian-cloud"]

  # Temporary VM specs
  machine_type = "e2-medium"
  disk_size    = 10

  # Result image name — {{timestamp}} guarantees uniqueness on every build
  image_name        = "wordpress-golden-{{timestamp}}"
  image_family      = "wordpress-golden"
  image_description = "Golden image with WordPress + Apache + PHP pre-installed"

  # Network for the temporary build VM
  network    = var.network
  subnetwork = var.subnetwork

  # SSH communication with the VM during build
  communicator            = "ssh"
  ssh_username            = "packer"
  temporary_key_pair_type = "ed25519"

  # With use_iap the VM has no external IP and SSH goes through an IAP tunnel (requires gcloud
  # on the machine running Packer). The tag matches the IAP SSH firewall rule of the VPC.
  # Without it, Packer connects straight to the VM's external IP.
  use_iap          = var.use_iap
  omit_external_ip = var.use_iap
  use_internal_ip  = var.use_iap
  tags             = var.use_iap ? ["iap-ssh-access"] : []
}

# Build steps executed inside the temporary VM
build {
  name    = "wordpress-golden"
  sources = ["source.googlecompute.wordpress"]

  # Step 1: upload installation script
  provisioner "file" {
    source      = "packer/scripts/install.sh"
    destination = "/tmp/install.sh"
  }

  # Step 2: run installation script
  provisioner "shell" {
    inline = [
      "chmod +x /tmp/install.sh",
      "sudo /tmp/install.sh"
    ]
  }

  # Step 3: verify everything was installed correctly
  provisioner "shell" {
    inline = [
      "/usr/sbin/apache2 -v",
      "php --version",
      "systemctl is-enabled apache2",
      "php -l /var/www/html/wp-config.php",
      "grep -q HTTP_X_FORWARDED_PROTO /var/www/html/wp-config.php"
    ]
  }
}