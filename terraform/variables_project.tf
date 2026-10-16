variable "project_id" {
  description = "ID for the Google Cloud project"
  type        = string
}

variable "environment" {
  description = "Environment of this deployment. Part of every resource name (see locals.tf)"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
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
  description = "Google account email granted IAP tunnel access for SSH into the WordPress instances"
  type        = string

  # Fail at plan time: an invalid IAM member is otherwise only rejected halfway through the apply.
  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.iap_user_email))
    error_message = "iap_user_email must be an email address. Set it with the _IAP_USER_EMAIL substitution in Cloud Build or TF_VAR_iap_user_email locally."
  }
}
