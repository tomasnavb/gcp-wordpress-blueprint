variable "name_prefix" {
  description = "Prefix name for the VM instances created by the MIG"
  type        = string
}

variable "machine_type" {
  description = "Machine type"
  type        = string
}

variable "region" {
  description = "Region for the MIG instances create. Regional HA"
  type        = string
}

variable "disk_size_gb" {
  description = "Disk size gb"
  type        = number
}

variable "image_family" {
  description = "Image family for the image utilized by the MIG"
  type        = string
}


variable "project_id" {
  description = "ID of the project utilized for image reference"
  type        = string
}

variable "network" {
  description = "Network"
  type        = string
}

variable "subnetwork" {
  description = "Subnetwork"
  type        = string
}

variable "tags" {
  description = "tags"
  type        = list(string)
}

locals {
  create_before_destroy = true
  auto_delete           = true
  boot                  = true
  image_family_path     = "projects/${var.project_id}/global/images/family/${var.image_family}"
  scopes                = ["cloud-platform"]
  disk_type             = "pd-standard"
}
