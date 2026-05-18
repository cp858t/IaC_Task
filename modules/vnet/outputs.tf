###############################################################################
# Module: vnet – Outputs
#
# Why these outputs?
# - vnet_id / vnet_name: Required by downstream modules (e.g., VM, AKS) that
#   must reference the VNET when creating NICs or peering.
# - subnet_ids: Almost always need to place resources in specific
#   subnets; returning a map keyed by name prevents hardcoding IDs.
# - subnet_address_prefixes: Useful for building firewall / NSG rules in
#   the calling module without duplicating CIDR values.
# - nsg_ids: Allows to attach additional rules or diagnostics to NSGs
#   created by this module.
# - vnet_address_space: Needed for peering
###############################################################################

output "vnet_id" {
  description = "The resource ID of the Virtual Network."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Name of the Virtual Network."
  value       = azurerm_virtual_network.this.name
}

output "vnet_address_space" {
  description = "Address space(s) of the Virtual Network."
  value       = azurerm_virtual_network.this.address_space
}

output "subnet_ids" {
  description = "Map of subnet name → subnet resource ID."
  value       = { for k, v in azurerm_subnet.this : k => v.id }
}

output "subnet_address_prefixes" {
  description = "Map of subnet name → list of address prefixes."
  value       = { for k, v in azurerm_subnet.this : k => v.address_prefixes }
}

output "nsg_ids" {
  description = "Map of subnet name → NSG resource ID (only for subnets with create_nsg = true)."
  value       = { for k, v in azurerm_network_security_group.this : k => v.id }
}

output "network_watcher_id" {
  description = "The resource ID of the Network Watcher, if created."
  value       = var.create_network_watcher ? azurerm_network_watcher.this[0].id : null
}
