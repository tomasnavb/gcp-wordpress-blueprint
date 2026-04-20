resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = var.subnet_name
  network       = google_compute_network.vpc.self_link
  region        = var.subnet_region
  ip_cidr_range = var.subnet_ip_cidr_range
}

resource "google_compute_firewall" "allow_ssh_icmp" {
  name     = "${var.vpc_name}-allow-ssh-icmp"
  network  = google_compute_network.vpc.self_link
  priority = 1000

  allow {
    protocol = "tcp"
    ports    = [22]
  }

  allow {
    protocol = "icmp"
  }

  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]

  target_tags = ["iap-ssh-access"]

}

resource "google_compute_firewall" "allow_external_lb" {
  name     = "${var.vpc_name}-allow-external-lb"
  network  = google_compute_network.vpc.self_link
  priority = 1000

  dynamic "allow" {
    for_each = var.allow_external_lb ? [1] : []
    content {
      protocol = "tcp"
      ports    = ["80", "443"]
    }
  }

  direction = "INGRESS"

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]

  target_tags = ["backend-service"]
}

resource "google_compute_router" "vpc_router" {
  count   = var.enable_nat ? 1 : 0
  name    = "${var.vpc_name}-router"
  network = google_compute_network.vpc.self_link
  region  = var.subnet_region

}

resource "google_compute_router_nat" "nat_config" {
  count  = var.enable_nat ? 1 : 0
  name   = "${google_compute_router.vpc_router.name}-nat"
  router = google_compute_router.vpc_router.name
  region = google_compute_router.vpc_router.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }


}
