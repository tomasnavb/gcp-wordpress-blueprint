variable "project_id" {
  type        = string
  description = "GCP project ID where the golden image will be created"
}

variable "zone" {
  type        = string
  description = "GCP zone where the temporary build VM will run"
  default     = "europe-west1-b"
}

variable "network" {
  type        = string
  description = "VPC network for the temporary Packer build VM"
  default     = "default"
}

variable "subnetwork" {
  type        = string
  description = "Subnet for the temporary Packer build VM"
  default     = ""
}