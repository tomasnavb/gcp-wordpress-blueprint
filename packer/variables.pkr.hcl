variable "project_id" {
  type        = string
  description = "GCP project ID where the golden image will be created"
}

variable "zone" {
  type        = string
  description = "GCP zone where the temporary build VM will run"
  default     = "europe-west1-b"
}

variable "environment" {
  type        = string
  description = "Environment of the deployment (dev or prod). Selects the build subnet the VM runs in"
  default     = "prod"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "The environment must be dev or prod."
  }
}

variable "use_iap" {
  type        = bool
  description = "Run the build VM in the build subnet, with no external IP, and connect through an IAP tunnel. Set to false only for the first build, which runs in the default network because the production VPC does not exist before the first terraform apply"
  default     = true
}

# Network of the build VM, built with the naming convention of terraform/locals.tf (vpc_name and
# build_subnet_name): change both together. The region is the zone without its last letter.
locals {
  region     = regex_replace(var.zone, "-[a-z]$", "")
  network    = var.use_iap ? "wp-blueprint-vpc-${var.environment}" : "default"
  subnetwork = var.use_iap ? "build-subnet-${var.environment}-${local.region}" : ""
}