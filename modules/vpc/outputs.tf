output "vpc_id" {
  value = google_compute_network.vpc.id
  description = "ID of the VPC network"
}