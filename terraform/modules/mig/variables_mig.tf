variable "mig_name" {
  description = "value"
  type        = string
}

variable "base_instance_name" {
  description = "value"
  type        = string
}

variable "distribution_policy_zones" {
  description = "value"
  type        = list(string)
}

variable "machine_type" {
  description = "Selected machine type for the VM instances"
  type        = string
  default     = "e2-medium"
}

locals {
  distribution_policy = "EVEN"
  # Ports
  named_port = "http"
  port       = 80
  # Autohealing
  initial_delay_sec = 60
  # Update Policy
  update_policy_type             = "PROACTIVE"
  update_policy_minimal_action   = "REPLACE"
  most_disruptive_allowed_action = "REPLACE"
  max_surge_fixed                = 1
  max_unavailable_fixed          = 0
}
