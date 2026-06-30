variable "project_id" {
  description = "ID for the Google Cloud project"
  type        = string
}

variable "project_region" {
  description = "Default GCP region for the project"
  type        = string
}

variable "project_zone" {
  description = "Default GCP zone for the project"
  type        = string
}

variable "iap_user_email" {
  description = "Google account email granted IAP tunnel access for SSH into the management VM"
  type        = string
}
