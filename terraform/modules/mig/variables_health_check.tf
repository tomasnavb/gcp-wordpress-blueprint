variable "health_check_name" {
  description = "Name for the global HTTP health check resource"
  type        = string
}

variable "check_interval_sec" {
  description = "How often the health check probe is sent to each instance (seconds)"
  type        = number
}

variable "timeout_sec" {
  description = "How long to wait for a health check response before marking it failed (seconds)"
  type        = number
}

variable "healthy_threshold" {
  description = "Number of consecutive successful probes before an instance is considered healthy"
  type        = number
}

variable "unhealthy_threshold" {
  description = "Number of consecutive failed probes before an instance is considered unhealthy and replaced"
  type        = number
}

variable "health_check_port" {
  description = "TCP port the health check probe connects to"
  type        = number
}

variable "request_path" {
  description = "HTTP path the health check requests (e.g. /wp-login.php to verify WordPress is responding)"
  type        = string
}
