# Production VPC, built with Google's official modules (terraform-google-modules), pinned to exact versions.
#
# Two subnets in the same region:
# - web: the WordPress instances of the MIG.
# - build: only the ephemeral VM Packer creates during an image build. Its own subnet and network tag keep
#   the build firewall rules apart from the web ones.
#
# Private Google Access on both: traffic to Google APIs (Secret Manager, Cloud Storage, Logging) goes
# straight to Google instead of through Cloud NAT. NAT is left for the internet (packages, downloads).
module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "18.3.1"

  depends_on = [google_project_service.gcp_services]

  project_id   = var.project_id
  network_name = local.vpc_name
  routing_mode = "REGIONAL"

  subnets = [
    {
      subnet_name           = local.web_subnet_name
      subnet_ip             = var.web_subnet_ip_cidr_range
      subnet_region         = var.project_region
      subnet_private_access = "true"
    },
    {
      subnet_name           = local.build_subnet_name
      subnet_ip             = var.build_subnet_ip_cidr_range
      subnet_region         = var.project_region
      subnet_private_access = "true"
    },
  ]

  # Rules that belong to the network itself. The rule that lets the Google front ends reach the
  # backends lives in the load balancer module, with the rest of the edge layer.
  ingress_rules = [
    {
      name          = local.fw_iap_ssh_web_name
      description   = "SSH through IAP to the WordPress instances"
      source_ranges = [local.iap_source_range]
      target_tags   = [local.web_ssh_network_tag]
      allow         = [{ protocol = "tcp", ports = ["22"] }]
    },
    {
      name          = local.fw_iap_ssh_build_name
      description   = "SSH through IAP to the ephemeral Packer build VM"
      source_ranges = [local.iap_source_range]
      target_tags   = [local.build_network_tag]
      allow         = [{ protocol = "tcp", ports = ["22"] }]
    },
  ]

  # The build VM sits in the same VPC as Cloud SQL's private IP, but has no reason to reach it.
  egress_rules = [
    {
      name               = local.fw_deny_build_to_psa_name
      description        = "The build VM cannot reach the Private Service Access range (Cloud SQL)"
      priority           = 1000
      destination_ranges = ["${google_compute_global_address.private_service_range.address}/${google_compute_global_address.private_service_range.prefix_length}"]
      target_tags        = [local.build_network_tag]
      deny               = [{ protocol = "all" }]
    },
  ]
}

# Cloud Router and Cloud NAT: outbound internet access for both subnets (package updates, the WordPress
# download during image builds) without external IPs. The router only holds the NAT configuration.
module "cloud_router" {
  source  = "terraform-google-modules/cloud-router/google"
  version = "9.1.0"

  project_id = var.project_id
  name       = local.router_name
  network    = module.vpc.network_name
  region     = var.project_region

  nats = [
    {
      name                               = local.nat_name
      nat_ip_allocate_option             = "AUTO_ONLY"
      source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
      log_config = {
        enable = true
        filter = "ERRORS_ONLY"
      }
    },
  ]
}
