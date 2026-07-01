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

  # SSH communication with the VM during build
  communicator            = "ssh"
  ssh_username            = "packer"
  temporary_key_pair_type = "ed25519"
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
      "systemctl is-enabled apache2"
    ]
  }
}