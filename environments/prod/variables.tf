# Environment: prod – Variables


variable "app_name" {
  type    = string
  default = "myapp"
  validation {
    condition     = can(regex("^[a-z0-9]{2,12}$", var.app_name))
    error_message = "app_name must be 2–12 lowercase alphanumeric characters."
  }
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "location" {
  type    = string
  default = "westus2"
}

variable "region_short" {
  type    = string
  default = "wus2"
}

variable "cost_center" {
  type    = string
  default = "engineering"
}

variable "owner" {
  type    = string
  default = "platform-team"
}

variable "vnet_address_space" {
  type    = list(string)
  default = ["10.20.0.0/16"]
}

variable "subnet_app_cidr" {
  type    = string
  default = "10.20.1.0/24"
}

variable "subnet_data_cidr" {
  type    = string
  default = "10.20.2.0/24"
}

variable "storage_allowed_ips" {
  type    = list(string)
  default = []
}

variable "enable_ddos_protection" {
  type    = bool
  default = false # Set true for real prod (cost consideration)
}

variable "vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

variable "vm_admin_username" {
  type    = string
  default = "azureadmin"
}

variable "vm_admin_ssh_public_key" {
  type      = string
  sensitive = true
}

variable "data_disk_size_gb" {
  type    = number
  default = 128
  validation {
    condition     = var.data_disk_size_gb >= 4 && var.data_disk_size_gb <= 4096
    error_message = "data_disk_size_gb must be between 4 and 4096."
  }
}
