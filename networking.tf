# Networks for production and management VPCs
resource "google_compute_network" "prod" {
  name                    = var.vpc_prod_name
  auto_create_subnetworks = false

}

resource "google_compute_network" "mgmt" {
  name                    = var.vpc_mgmt_name
  auto_create_subnetworks = false

}

# Subnetworks for production and management VPCs
resource "google_compute_subnetwork" "prod" {
  name          = var.subnet_prod_name
  network       = google_compute_network.prod.self_link
  region        = var.subnet_prod_region
  ip_cidr_range = var.subnet_prod_ip_cidr_range
}

resource "google_compute_subnetwork" "mgmt" {
  name          = var.subnet_mgmt_name
  network       = google_compute_subnetwork.mgmt.self_link
  region        = var.subnet_mgmt_region
  ip_cidr_range = var.subnet_mgmt_ip_cidr_range

}

# Firewall rules for production and management VPCs
resource "google_compute_firewall" "allow_ssh_icmp_prod" {
  name     = "prod-vpc-allow-ssh-icmp"
  network  = google_compute_network.prod.self_link
  priority = 1000

  allow {
    protocol = "tcp"
    ports    = [22]
  }

  allow {
    protocol = "icmp"
  }

  direction = "INGRESS"

  source_ranges = [
    "35.235.240.0/20",
    google_compute_subnetwork.mgmt.ip_cidr_range
  ]

  target_tags = ["prod-vm"]
}

resource "google_compute_firewall" "allow_ssh_mgmt" {
  name     = "mgmt-vpc-allow-ssh-icmp"
  network  = google_compute_network.prod.self_link
  priority = 1000

  allow {
    protocol = "tcp"
    ports    = [22]
  }

  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]

  target_tags = ["mgmt-vm"]

}

# Router for Cloud NAT
resource "google_compute_router" "main" {
  name = "wordpress-site-nat-router"

}

# Cloud NAT configuration for the production VPC to allow outbound internet access for instances without external IPs
resource "google_compute_router_nat" "main" {
  name                               = "wordpress-site-nat"
  router                             = google_compute_router.main.self_link
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

}
