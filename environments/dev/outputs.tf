###############################################################################
# Environment: dev – Outputs
#
# Why these outputs?
# - resource_group_name: Needed by CI pipelines to scope Azure CLI commands.
# - vnet_id/subnet_ids: Required if a separate Terraform workspace deploys
#   resources into this VNET (data source lookup by ID).
# - vm_public_ip: Allows CI to SSH in after deploy to run smoke tests.
# - storage_account_*: Required by applications reading config at startup.
# - vm_principal_id: Needed to grant additional role assignments externally.
###############################################################################

output "resource_group_name" {
  description = "Name of the resource group containing all dev resources."
  value       = azurerm_resource_group.main.name
}

output "vnet_id" {
  description = "Resource ID of the dev VNET."
  value       = module.vnet.vnet_id
}

output "vnet_name" {
  description = "Name of the dev VNET."
  value       = module.vnet.vnet_name
}

output "subnet_ids" {
  description = "Map of subnet name → resource ID."
  value       = module.vnet.subnet_ids
}

output "vm_name" {
  description = "Name of the dev Virtual Machine."
  value       = azurerm_linux_virtual_machine.main.name
}

output "vm_public_ip" {
  description = "Public IP address of the dev VM (for SSH / smoke tests)."
  value       = azurerm_public_ip.vm.ip_address
}

output "vm_principal_id" {
  description = "System-assigned managed identity principal ID of the VM."
  value       = azurerm_linux_virtual_machine.main.identity[0].principal_id
}

output "storage_account_name" {
  description = "Name of the Storage Account."
  value       = azurerm_storage_account.main.name
}

output "storage_account_primary_endpoint" {
  description = "Primary blob endpoint URL."
  value       = azurerm_storage_account.main.primary_blob_endpoint
  sensitive   = true
}

output "artifacts_container_name" {
  description = "Name of the blob container for build artifacts."
  value       = azurerm_storage_container.artifacts.name
}
