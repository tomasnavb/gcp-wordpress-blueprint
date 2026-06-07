variable "autoscaler_name" {
  description = "value"
  type        = string
}

variable "autoscaler_region" {
  description = "value"
  type        = string
}

variable "min_replicas" {
  description = "value"
  type        = number
}

variable "max_replicas" {
  description = "value"
  type        = number
}

variable "cooldown_period" {
  description = "value"
  type        = number
}

variable "lb_utilization_target" {
  description = "value"
  type        = number
}

variable "max_scaled_in_replicas" {
  description = "value"
  type        = number
}

variable "time_window_sec" {
  description = "value"
  type        = number
}