variable "project_id" {
  type        = string
  description = "GCP project ID where the golden image will be created"
}

variable "zone" {
  type        = string
  description = "GCP zone where the temporary build VM will run"
  default     = "us-central1-a"
}