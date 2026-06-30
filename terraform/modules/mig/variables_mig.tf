variable "mig_name" {
  description = "Name for the regional managed instance group"
  type        = string
}

variable "base_instance_name" {
  description = "Base name used when the MIG creates individual VM instances"
  type        = string
}

variable "distribution_policy_zones" {
  description = "Zones within the region where the MIG distributes instances for HA"
  type        = list(string)
}

variable "distribution_policy_target_shape" {
  description = "Instance distribution strategy across zones (EVEN or ANY)"
  type        = string
}

variable "port_name" {
  description = "Named port exposed by the MIG and referenced by the load balancer backend service"
  type        = string
}

variable "port" {
  description = "Port number associated with the named port"
  type        = number
}

variable "initial_delay_sec" {
  description = "Seconds to wait after an instance starts before the auto-healer begins checking its health"
  type        = number
}

variable "update_policy_type" {
  description = "Rolling update strategy: PROACTIVE (applies immediately) or OPPORTUNISTIC (applies on instance recreation)"
  type        = string
}

variable "update_policy_minimal_action" {
  description = "Least disruptive action taken on each instance during a rolling update"
  type        = string
}

variable "most_disruptive_allowed_action" {
  description = "Most disruptive action allowed per instance during a rolling update (REPLACE, RESTART, or REFRESH)"
  type        = string
}

variable "max_surge_fixed" {
  description = "Maximum number of additional instances that can be created above target size during a rolling update"
  type        = number
}

variable "max_unavailable_fixed" {
  description = "Maximum number of instances that can be unavailable during a rolling update"
  type        = number
}
