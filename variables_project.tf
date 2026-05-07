variable "project_id" {
  description = "ID for the Google Cloud project"
  type        = string
}

variable "project_region" {
  description = "Google Cloud project region"
  type        = string
  default     = "europe-west9"
}

variable "project_zone" {
  description = "Google Cloud project zone"
  type        = string
  default     = "europe-west9"
}