variable "vm_instance_name" {
  description = "Name of the Compute Engine instance"
  type        = string
  default     = "wordpress-vm"
}

variable "vm_machine_type" {
  description = "Machine type for the VM instance"
  type        = string
  default     = "e2-medium"
}

variable "instance_tags" {
  description = "Tags to apply to the VM instance"
  type        = list(string)
}

variable "vpc_id" {
    description = "ID of the VPC network to which the VM instance will be connected"
    type        = string  
}

variable "subnet_id" {
    description = "ID of the subnet to which the VM instance will be connected"
    type        = string
}

variable "boot_disk_image" {
  description = "Boot disk image for the VM instance"
  type        = string
  default     = "debian-cloud/debian-11"

}

variable "boot_disk_size_gb" {
  description = "Disk size for the VM boot disk. Default 10GB for small instances"
  type        = string
  default     = "10GB"
}

variable "boot_disk_type" {
  description = "Disk type for the VM boot disk. Default pd-standard"
  type        = string
  default     = "pd-standard"
}

variable "start_up_script_path" {
    description = "Path to the startup script to be executed when the VM instance starts"
    type        = string
}

variable "vm_service_account_email" {
    description = "Email of the service account to attach to the VM instance for authentication and permissions"
    type        = string
    default = null
}