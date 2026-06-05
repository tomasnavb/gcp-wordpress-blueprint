resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = local.auto_create_subnets
}

resource "google_compute_subnetwork" "subnet" {
  name          = var.subnet_name
  network       = google_compute_network.vpc.self_link
  region        = var.subnet_region
  ip_cidr_range = var.subnet_ip_cidr_range
}

resource "google_compute_firewall" "allow_ssh_from_iap" {
  name     = local.allow_ssh_iap_name
  network  = google_compute_network.vpc.self_link
  priority = local.default_priority

  dynamic "allow" {
    for_each = var.allow_ssh_from_iap ? [1] : []
    content {
      protocol = local.tcp_protocol
      ports    = [local.ssh_port]
    }
  }

  direction = local.iap_allow_ssh_direction

  source_ranges = local.iap_ip_ranges

  target_tags = local.iap_target_tags

}

resource "google_compute_firewall" "allow_external_lb" {
  name     = local.allow_external_lb_name
  network  = google_compute_network.vpc.self_link
  priority = local.default_priority

  dynamic "allow" {
    for_each = var.allow_external_lb ? [1] : []
    content {
      protocol = local.tcp_protocol
      ports    = [local.tcp_traffic_port]
    }
  }

  direction = local.ingress_fr

  source_ranges = local.lb_source_ranges

  target_tags = local.backend_tags
}

resource "google_compute_router" "vpc_router" {
  count   = var.enable_nat ? 1 : 0
  name    = local.router_name
  network = google_compute_network.vpc.self_link
  region  = var.subnet_region

}

resource "google_compute_router_nat" "nat_config" {
  count  = var.enable_nat ? 1 : 0
  name   = local.nat_name
  router = google_compute_router.vpc_router[0].name
  region = google_compute_router.vpc_router[0].region

  nat_ip_allocate_option             = local.nat_ip_allocation_option
  source_subnetwork_ip_ranges_to_nat = local.nat_source_subnets

  log_config {
    enable = local.enable_log_config
    filter = local.log_filter
  }


}
