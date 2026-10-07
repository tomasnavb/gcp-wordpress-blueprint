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

  # Fail at plan time: an invalid IAM member is otherwise only rejected halfway through the apply.
  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.iap_user_email))
    error_message = "iap_user_email must be an email address. Set it with the _IAP_USER_EMAIL substitution in Cloud Build or TF_VAR_iap_user_email locally."
  }
}
