# Reserve an IP range for private service access
resource "google_compute_global_address" "private_service_range" {
  name          = "private-service-range"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = module.vpc_prod.vpc_id
}

# Create the private connection
resource "google_service_networking_connection" "private_connection" {
  network                 = module.vpc_prod.vpc_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_range.name]

  # Ensures Cloud SQL is destroyed before this connection during terraform destroy,
  # preventing the "Producer services still using this connection" error.
  depends_on = [google_sql_database_instance.main]
}
