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
#
# deletion_policy = "ABANDON": on destroy, Terraform removes the connection from the state without
# deleting it in GCP. After the Cloud SQL instance is deleted, Google keeps reporting this connection
# as in use for a while and rejects its deletion ("Producer services (e.g. CloudSQL, ...) are still
# using this connection"), which stopped terraform destroy. The abandoned connection goes away with
# the VPC. Destroy order is unchanged: the instance first, then this connection, then the reserved
# range and the VPC. If the destroy still stops on the range or the VPC because of the peering, see
# E5 in docs/devlogs/devlog-2026-10-07-verification.md.
resource "google_service_networking_connection" "private_connection" {
  network         = module.vpc_prod.vpc_id
  service         = "servicenetworking.googleapis.com"
  deletion_policy = "ABANDON"

  reserved_peering_ranges = [google_compute_global_address.private_service_range.name]
}
