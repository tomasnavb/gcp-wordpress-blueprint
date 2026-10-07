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

variable "use_iap" {
  type        = bool
  description = "Connect to the build VM through an IAP tunnel, with no external IP. Set to false only for the first build, which runs in the default network before the management VPC exists"
  default     = true
}