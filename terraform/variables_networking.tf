# Production VPC subnets. Names come from locals.tf; only the ranges are configurable.
variable "web_subnet_ip_cidr_range" {
  description = "IP CIDR range of the web subnet, where the WordPress instances run"
  type        = string
  default     = "10.0.0.0/24"
}

variable "build_subnet_ip_cidr_range" {
  description = "IP CIDR range of the build subnet, which only hosts the ephemeral Packer VM during an image build"
  type        = string
  default     = "10.0.1.0/28"
}
