locals {
  iap_fw_rule_name = "${var.vpc_name}-allow-iap-ssh"
  router_name      = "${var.vpc_name}-router"
  nat_name         = "${var.vpc_name}-nat"
}

resource "google_compute_network" "this" {
  name                    = var.vpc_name
  auto_create_subnetworks = var.auto_create_subnets
}

resource "google_compute_subnetwork" "subnet" {
  name          = var.subnet_name
  network       = google_compute_network.this.self_link
  region        = var.region
  ip_cidr_range = var.subnet_ip_cidr_range
}

resource "google_compute_firewall" "allow_ssh_from_iap" {
  count     = var.allow_ssh_from_iap ? 1 : 0
  name      = local.iap_fw_rule_name
  network   = google_compute_network.this.self_link
  priority  = var.iap_fw_rule_priority
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [22]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = var.iap_target_tags
}

resource "google_compute_router" "this" {
  count   = var.enable_nat ? 1 : 0
  name    = local.router_name
  network = google_compute_network.this.self_link
  region  = var.region
}

resource "google_compute_router_nat" "this" {
  count  = var.enable_nat ? 1 : 0
  name   = local.nat_name
  router = google_compute_router.this[0].name
  region = google_compute_router.this[0].region

  nat_ip_allocate_option             = var.nat_ip_allocate_option
  source_subnetwork_ip_ranges_to_nat = var.source_subnetwork_ip_ranges_to_nat

  log_config {
    enable = var.enable_nat_log_config
    filter = var.nat_log_filter
  }
}
