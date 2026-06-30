variable "autoscaler_name" {
  description = "Name for the regional autoscaler resource"
  type        = string
}

variable "min_replicas" {
  description = "Minimum number of instances the autoscaler maintains regardless of load"
  type        = number
}

variable "max_replicas" {
  description = "Maximum number of instances the autoscaler can scale up to"
  type        = number
}

variable "cooldown_period" {
  description = "Seconds the autoscaler waits after a scaling event before re-evaluating (allows new instances to warm up)"
  type        = number
}

variable "lb_utilization_target" {
  description = "Target load balancing utilization ratio (0.0–1.0) the autoscaler maintains"
  type        = number
}

variable "max_scaled_in_replicas" {
  description = "Maximum number of instances the autoscaler can remove in a single scale-in window"
  type        = number
}

variable "time_window_sec" {
  description = "Time window in seconds over which the scale-in control limit is evaluated"
  type        = number
}
