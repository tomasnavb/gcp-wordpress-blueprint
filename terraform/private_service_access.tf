# Reserve an IP range for private service access
resource "google_compute_global_address" "private_service_range" {
  name          = "private-service-range"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = module.vpc_prod.id
}

# Create the private connection
resource "google_service_networking_connection" "private_connection" {
  network                 = module.vpc_prod.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_range.name]
}
