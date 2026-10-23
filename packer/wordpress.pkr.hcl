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
  source_image_family     = "debian-12"
  source_image_project_id = ["debian-cloud"]

  # Temporary VM specs
  machine_type = "e2-medium"
  disk_size    = 10

  # Result image name — {{timestamp}} guarantees uniqueness on every build
  image_name        = "wp-blueprint-web-{{timestamp}}"
  image_family      = "wp-blueprint-web" # Must match local.image_family in terraform/locals.tf
  image_description = "Golden image with WordPress + Apache + PHP pre-installed"

  # Network for the temporary build VM: the build subnet of the production VPC, or the default
  # network for the first build (variables.pkr.hcl)
  network    = local.network
  subnetwork = local.subnetwork

  # No service account: the VM only installs packages from the internet and needs no Google
  # credentials. Without this it would run as the Compute Engine default service account, whose
  # permissions anything running in the VM could use through the metadata server. The image is
  # created by Packer from outside, with the pipeline's service account, after the VM is stopped.
  disable_default_service_account = true

  # SSH communication with the VM during build
  communicator            = "ssh"
  ssh_username            = "packer"
  temporary_key_pair_type = "ed25519"

  # With use_iap the VM has no external IP and SSH goes through an IAP tunnel (requires gcloud
  # on the machine running Packer). The tag matches the build firewall rules of the VPC: IAP SSH
  # allowed, egress to Cloud SQL's private range denied (local.build_network_tag in
  # terraform/locals.tf). Without IAP, Packer connects straight to the VM's external IP.
  use_iap          = var.use_iap
  omit_external_ip = var.use_iap
  use_internal_ip  = var.use_iap
  tags             = var.use_iap ? ["packer-build"] : []
}

# Build steps executed inside the temporary VM
build {
  name    = "wp-blueprint-web"
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
      "grep -q HTTP_X_FORWARDED_PROTO /var/www/html/wp-config.php",
      "grep -q DISALLOW_FILE_MODS /var/www/html/wp-config.php",
      "gcsfuse --version",
      "test -d /var/www/html/wp-content/uploads",
      "php -l /var/www/html/health.php",
      "if curl -sf -o /dev/null http://localhost/health.php; then echo 'health.php must not report healthy in the image'; exit 1; fi"
    ]
  }
}