variable "instance_template_name_prefix" {
  description = "Name prefix for the instance template (a timestamp suffix is auto-appended)"
  type        = string
}

variable "machine_type" {
  description = "Machine type for production WordPress instances"
  type        = string
}

variable "instance_template_tags" {
  description = "Network tags applied to instances (used for firewall rule targeting)"
  type        = list(string)
}

variable "mig_name" {
  description = "Name for the regional managed instance group"
  type        = string
}

variable "base_instance_name" {
  description = "Base name for instances created by the MIG"
  type        = string
}

variable "distribution_policy_zones" {
  description = "Zones within the region where the MIG distributes instances"
  type        = list(string)
}

variable "distribution_policy_target_shape" {
  description = "How instances are distributed across zones (EVEN or ANY)"
  type        = string
}

variable "port_name" {
  description = "Named port exposed by the MIG (referenced by the load balancer backend)"
  type        = string
}

variable "port" {
  description = "Port number for the named port"
  type        = number
}

variable "update_policy_type" {
  description = "Type of rolling update policy (PROACTIVE or OPPORTUNISTIC)"
  type        = string
}

variable "update_policy_minimal_action" {
  description = "Minimal action to perform on instances during a rolling update"
  type        = string
}

variable "most_disruptive_allowed_action" {
  description = "Most disruptive action allowed during rolling update (REPLACE, RESTART, REFRESH)"
  type        = string
}

variable "max_surge_fixed" {
  description = "Maximum number of additional instances created during a rolling update"
  type        = number
}

variable "max_unavailable_fixed" {
  description = "Maximum number of instances that can be unavailable during a rolling update"
  type        = number
}

variable "initial_delay_sec" {
  description = "Seconds to wait after an instance starts before checking health (auto-healing)"
  type        = number
}

variable "health_check_name" {
  description = "Name for the HTTP health check resource"
  type        = string
}

variable "check_interval_sec" {
  description = "How often the health check runs (seconds)"
  type        = number
}

variable "timeout_sec" {
  description = "How long to wait for a health check response before marking it as failed (seconds)"
  type        = number
}

variable "healthy_threshold" {
  description = "Number of consecutive successful checks before an instance is considered healthy"
  type        = number
}

variable "unhealthy_threshold" {
  description = "Number of consecutive failed checks before an instance is considered unhealthy"
  type        = number
}

variable "health_check_port" {
  description = "Port the health check probes"
  type        = number
}

variable "request_path" {
  description = "HTTP path the health check requests"
  type        = string
}

variable "autoscaler_name" {
  description = "Name for the regional autoscaler resource"
  type        = string
}

variable "min_replicas" {
  description = "Minimum number of instances the autoscaler maintains"
  type        = number
}

variable "max_replicas" {
  description = "Maximum number of instances the autoscaler can scale up to"
  type        = number
}

variable "cooldown_period" {
  description = "Seconds the autoscaler waits after a scale event before evaluating again"
  type        = number
}

variable "lb_utilization_target" {
  description = "Target load balancing utilization ratio (0.0–1.0) the autoscaler aims for"
  type        = number
}

variable "max_scaled_in_replicas" {
  description = "Maximum number of instances the autoscaler can remove in one scale-in window"
  type        = number
}

variable "time_window_sec" {
  description = "Time window (seconds) over which the scale-in control limit is evaluated"
  type        = number
}
