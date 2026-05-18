###############################################################################
# Environment: dev – Variables
###############################################################################

variable "app_name" {
  type        = string
  description = "Short application or project name used in resource naming (lowercase, no spaces)."
  default     = "myapp"

  validation {
    condition     = can(regex("^[a-z0-9]{2,12}$", var.app_name))
    error_message = "app_name must be 2–12 lowercase alphanumeric characters."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment identifier."
  default     = "dev"
}

variable "location" {
  type        = string
  description = "Azure region for all resources."
  default     = "eastus"
}

variable "region_short" {
  type        = string
  description = "Short region code appended to resource names (e.g., 'eus' for eastus)."
  default     = "eus"
}

variable "cost_center" {
  type        = string
  description = "Cost center tag value for billing attribution."
  default     = "engineering"
}

variable "owner" {
  type        = string
  description = "Team or individual responsible for this environment."
  default     = "platform-team"
}

# ── Networking ──────────────────────────────────────────────────────────────

variable "vnet_address_space" {
  type        = list(string)
  description = "CIDR block(s) for the VNET."
  default     = ["10.10.0.0/16"]
}

variable "subnet_app_cidr" {
  type        = string
  description = "CIDR for the application subnet."
  default     = "10.10.1.0/24"
}

variable "subnet_data_cidr" {
  type        = string
  description = "CIDR for the data/storage subnet."
  default     = "10.10.2.0/24"
}

variable "allowed_ssh_cidr" {
  type        = string
  description = "Source IP/CIDR allowed to SSH into the VM. Restrict to your office or VPN IP."
  default     = "0.0.0.0/0" # CHANGE in production!
}

# ── Storage ─────────────────────────────────────────────────────────────────

variable "storage_allowed_ips" {
  type        = list(string)
  description = "Public IPs allowed through the Storage Account firewall."
  default     = []
}

# ── Virtual Machine ──────────────────────────────────────────────────────────

variable "vm_size" {
  type        = string
  description = "Azure VM SKU."
  default     = "Standard_B2s"
}

variable "vm_admin_username" {
  type        = string
  description = "Admin username for the Linux VM."
  default     = "azureadmin"
}

variable "vm_admin_ssh_public_key" {
  type        = string
  description = "SSH public key content for the VM admin user (required)."
  sensitive   = true
}

variable "data_disk_size_gb" {
  type        = number
  description = "Size in GB of the additional managed data disk."
  default     = 32

  validation {
    condition     = var.data_disk_size_gb >= 4 && var.data_disk_size_gb <= 4096
    error_message = "data_disk_size_gb must be between 4 and 4096."
  }
}
