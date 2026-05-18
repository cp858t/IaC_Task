# Module: vnet – Variables


variable "vnet_name" {
  type        = string
  description = "Name of the Virtual Network."

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-_.]{1,62}[a-zA-Z0-9_]$", var.vnet_name))
    error_message = "vnet_name must be 3–64 characters, start and end with alphanumeric, and contain only letters, numbers, hyphens, underscores, or periods."
  }
}

variable "location" {
  type        = string
  description = "Azure region where the VNET will be created (e.g., 'eastus', 'westeurope')."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the Resource Group in which to deploy the VNET."
}

variable "environment" {
  type        = string
  description = "Deployment environment name (e.g., 'dev', 'staging', 'prod')."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "address_space" {
  type        = list(string)
  description = "List of CIDR blocks assigned to the VNET (e.g., [\"10.0.0.0/16\"])."

  validation {
    condition     = length(var.address_space) > 0
    error_message = "At least one address space CIDR must be provided."
  }
}

variable "dns_servers" {
  type        = list(string)
  default     = []
  description = "Custom DNS server IP addresses. Leave empty to use Azure-provided DNS."
}

variable "subnets" {
  description = <<-EOT
    List of subnet definitions. Each object supports the following fields:
    - name             (string, required) – subnet name
    - address_prefixes (list(string), required) – CIDR(s) for the subnet
    - create_nsg       (bool, optional, default false) – attach a new NSG
    - nsg_rules        (list(object), optional) – security rules for the NSG
    - delegation       (object, optional) – service delegation block
  EOT

  type = list(object({
    name             = string
    address_prefixes = list(string)
    create_nsg       = optional(bool, false)
    nsg_rules = optional(list(object({
      name                       = string
      priority                   = number
      direction                  = string
      access                     = string
      protocol                   = string
      source_port_range          = optional(string, "*")
      destination_port_range     = optional(string)
      destination_port_ranges    = optional(list(string))
      source_address_prefix      = optional(string, "*")
      destination_address_prefix = optional(string, "*")
    })), [])
    delegation = optional(object({
      name                    = string
      service_delegation_name = string
      actions                 = optional(list(string), [])
    }))
  }))
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags to apply to all resources in the module. Module-level tags (environment, region, managed_by) are always added."
}

variable "enable_ddos_protection" {
  type        = bool
  default     = false
  description = "Whether to create and attach an Azure DDoS Protection Standard plan. Note: this incurs significant cost."
}

variable "create_network_watcher" {
  type        = bool
  default     = false
  description = "Whether to create a Network Watcher in this region. Only one Network Watcher per region per subscription should exist."
}
